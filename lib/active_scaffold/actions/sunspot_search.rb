module ActiveScaffold::Actions
  module SunspotSearch
    include ActiveScaffold::Actions::CommonSunspotSearch
    def self.included(base)
      base.before_filter :sunspot_search_authorized_filter, :only => :show_sunspot_search
      base.before_filter :store_sunspot_search_params_into_session, :only => [:index]
      base.before_filter :do_sunspot_search, :only => [:index]
      base.helper_method :sunspot_search_params

      #set path for plugin views
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

    def do_sunspot_search
      query = sunspot_search_params.to_s.strip rescue ''
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

    def sunspot_solr_condition(query)
      begin
        search = Document.search() do
          keywords(query)
        end
      rescue Errno::ECONNREFUSED => e
        @error = 'Documents search service is down!'
        puts @error
        return [] # :TODO - return error to interface
      end
      
      results = search.results
      results.nil? ? [] : build_database_search_condition(results.map(&:id))
    end

    private    
    # Builds search condition for database query    
    # * return an array like [documents.id = 1] if solr return only 1 `id` or
    # * return an array like [documents.id IN (1,2,3)] if solr return only more ids
    def build_database_search_condition(ids)
      operator = (ids.count == 1) ? '= ?' : ' IN (?)'
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
    
  end
end
