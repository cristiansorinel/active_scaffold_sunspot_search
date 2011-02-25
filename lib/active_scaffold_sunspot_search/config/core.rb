ActiveScaffold::Config::Core.class_eval do
  ActionDispatch::Routing::ACTIVE_SCAFFOLD_CORE_ROUTING[:collection][:show_sunspot_search] = :get  
end