module ActiveScaffold::Actions
  module CommonSunspotSearch
    protected
    def store_sunspot_search_params_into_session
      active_scaffold_session_storage[:sunspot_search] = params.delete :sunspot_search if params[:sunspot_search]
    end
    
    def sunspot_search_params
      active_scaffold_session_storage[:sunspot_search]
    end

    def search_ignore?
      active_scaffold_config.list.always_show_search
    end
    
    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def search_authorized?
      authorized_for?(:crud_type => :read)
    end
  end
end
