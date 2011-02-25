require 'active_scaffold'
require "active_scaffold_sunspot_search/config/core.rb"

module ActiveScaffold
  
  module Actions    
    ActiveScaffold.autoload_subdir('actions', self)    
  end

  module Extensions
    ActiveScaffold.autoload_subdir('config', self)
  end
  
end