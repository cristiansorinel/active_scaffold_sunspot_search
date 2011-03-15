module ActiveScaffold::Actions
  module SunspotSearch
    include ActiveScaffold::Actions::CommonSearch
    def self.included(base)
      base.before_filter :sunspot_search_authorized_filter, :only => :show_sunspot_search
      base.before_filter :store_search_params_into_session, :only => [:index]
      base.before_filter :do_sunspot_search, :only => [:index]
      base.helper_method :search_params

      #set path for plugin's views
      as_sunspot_search_plugin_path = File.join(ActiveScaffold::Config::SunspotSearch.plugin_directory, 'frontends', 'default' , 'views')
      base.add_active_scaffold_path as_sunspot_search_plugin_path
    end
    
    def show_sunspot_search
      respond_to_action(:sunspot_search)
    end

    protected
    def sunspot_search_respond_to_html
      render(:action => "sunspot_search")
    end
    def sunspot_search_respond_to_js
      render(:partial => "sunspot_search")
    end

    #if the user doesn't specify something to search by, it will take records from Database directly
    def do_sunspot_search
      query = search_params.to_s.strip rescue ''
      unless query.empty?
        columns = active_scaffold_config.sunspot_search.columns
        condition = sunspot_solr_condition(query)
        if @error.blank?
          self.active_scaffold_conditions = merge_conditions(self.active_scaffold_conditions, condition)
          @filtered = true

          includes_for_search_columns = columns.collect{ |column| column.includes}.flatten.uniq.compact
          self.active_scaffold_includes.concat includes_for_search_columns

          active_scaffold_config.list.user.page = nil
        else
          flash.now[:error] = @error
        end
      end
    end

    #override this in your controller to specify custom conditions
    # Example
    #   def conditions_for_solr_search(solr, query)
    #      solr.all_of do
    #        solr.keywords(query) unless query.blank?
    #        if not project.owner_id == current_user.id
    #          solr.with(:project_role_ids).any_of(current_user.project_role_ids)
    #        end
    #        solr.with(:project_id).equal_to(project.id)
    #        solr.order_by(:created_at, :desc)
    #      end     
    #   end
    #
    def conditions_for_solr_search(solr, query)
      query.blank? ? nil : solr.keywords(query)
    end

    # solr will search by conditions specified in conditions_for_solr_search
    # * it will return the ids of the documents and i will search by those ids in Database
    # * I do his because the ids will come paginated from solr -> see paginate(pagination_parameters)
    # * This functions returns something as documents.id IN (1,2,3) or as documents.id = 1 or
    # * documents.id = NULL when the search returns an empty array
    def sunspot_solr_condition(query)
      begin
        current = self
        search = active_scaffold_config.model.search() do
          current.send :conditions_for_solr_search, self, query          
          paginate(:page => (params[:page].present? ? params[:page] : 1),
            :per_page => active_scaffold_config.list.user.per_page
          )
        end        
      rescue Errno::ECONNREFUSED => e
        @error = 'Search service not available!'
        return []
      end

      @count_solr_result = search.total
      ids = search.hits.map &:primary_key
      build_database_search_condition(ids)
    end    

    private

    # Builds search condition for database query
    # * if solr return [] = (no document id), then I return documents.id = NULL
    # * this way I'm sure nothing will be returned from the database
    # * return an array like [documents.id = 1] if solr return only one `id` or
    # * return an array like [documents.id IN (1,2,3)] if solr return only more ids
    def build_database_search_condition(ids)      
      operator = case ids.count
      when 0 then ' = NULL '
      when 1 then ' = ? '
      else ' IN (?) '
      end
      
      table = active_scaffold_config.model.table_name
      primary_key = active_scaffold_config.model.primary_key
      ["#{table}.#{primary_key} #{operator}", ids]
    end

    def sunspot_search_authorized_filter
      link = active_scaffold_config.sunspot_search.link || active_scaffold_config.sunspot_search.class.link
      raise ActiveScaffold::ActionNotAllowed unless self.send(link.security_method)
    end
    def sunspot_search_formats
      (default_formats + active_scaffold_config.formats + active_scaffold_config.sunspot_search.formats).uniq
    end

    # NOTE! This overrides a huge piece of AS and must be kept in sync
    #
    # If we search by a keyword in solr, we know the total number of documents returned
    # retained in @count_solr_result = search.total
    # I added finder_options.merge!(:offset => offset) unless @count_solr_result.present?
    # to avoid pagination in database when it was already done using solr
    def find_page(options = {})
      options.assert_valid_keys :sorting, :per_page, :page, :count_includes, :pagination

      search_conditions = all_conditions
      full_includes = (active_scaffold_includes.blank? ? nil : active_scaffold_includes)
      options[:per_page] ||= 999999999
      options[:page] ||= 1
      options[:count_includes] ||= full_includes unless search_conditions.nil?

      klass = beginning_of_chain

      # create a general-use options array that's compatible with Rails finders
      finder_options = { :order => options[:sorting].try(:clause),
        :where => search_conditions,
        :joins => joins_for_finder,
        :includes => options[:count_includes]}

      finder_options.merge! custom_finder_options

      # If we search by a keyword in solr, we know the total number of documents returned
      if @count_solr_result.present?        
        count = @count_solr_result 
      else
        # NOTE: we must use :include in the count query, because some conditions may reference other tables
        count_query = append_to_query(klass, finder_options.reject{|k, v| [:select, :order].include?(k)})
        count = count_query.count unless options[:pagination] == :infinite

        # Converts count to an integer if ActiveRecord returned an OrderedHash
        # that happens when finder_options contains a :group key
        count = count.length if count.is_a? ActiveSupport::OrderedHash
      end
            
      finder_options.merge! :includes => full_includes
      # we build the paginator differently for method- and sql-based sorting
      if options[:sorting] and options[:sorting].sorts_by_method?
        pager = ::Paginator.new(count, options[:per_page]) do |offset, per_page|
          sorted_collection = sort_collection_by_column(append_to_query(klass, finder_options).all, *options[:sorting].first)
          sorted_collection = sorted_collection.slice(offset, per_page) if options[:pagination]
          sorted_collection
        end
      else
        pager = ::Paginator.new(count, options[:per_page]) do |offset, per_page|
          if options[:pagination]
            finder_options.merge!(:limit => per_page)
            # to avoid pagination in database when it was already done using solr
            finder_options.merge!(:offset => offset) unless @count_solr_result.present?
            append_to_query(klass, finder_options).all
          end
        end
      end
      pager.page(options[:page])
    end
    
  end
end