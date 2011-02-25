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
        #text_search = active_scaffold_config.sunspot_search.text_search
        #sunspot_search_conditions = self.class.create_conditions_for_columns(query.split(' '), columns, text_search)
        #self.active_scaffold_conditions = merge_conditions(self.active_scaffold_conditions, sunspot_search_conditions)
        @filtered = true #!sunspot_search_conditions.blank?

        includes_for_search_columns = columns.collect{ |column| column.includes}.flatten.uniq.compact
        self.active_scaffold_includes.concat includes_for_search_columns

        active_scaffold_config.list.user.page = nil
      end
    end

    def conditions_for_collection      
      search_condition = session["as:utilisation/documents"][:sunspot_search]
      if search_condition.blank?
        return []
      end
      
      begin
        search = Document.search() do
          keywords(search_condition)
        end
      rescue Errno::ECONNREFUSED => e        
        return []
      end

      results = search.results
      cond = results.map &:id

      model_table = active_scaffold_config.model.table_name
      model_primary_key = active_scaffold_config.model.primary_key

      results.nil? ? [] : ["#{model_table}.#{model_primary_key} IN (?)", cond]
    end

    private
    def sunspot_search_authorized_filter
      link = active_scaffold_config.sunspot_search.link || active_scaffold_config.sunspot_search.class.link
      raise ActiveScaffold::ActionNotAllowed unless self.send(link.security_method)
    end
    def sunspot_search_formats
      (default_formats + active_scaffold_config.formats + active_scaffold_config.sunspot_search.formats).uniq
    end
    
  end
end
