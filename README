Active scaffold plugin for searching with Sunspot Solr

### Install

rails plugin install git://github.com/cristiansorinel/active_scaffold_sunspot_search.git

### Usage

Supposing you have a sunspot-enabled model like:

    class Comment < ActiveRecord::Base
      searchable do
        text :name
        integer :post_id
      end
    end

To use it, in your controller swap the default active scaffold search action with solr_search action like this:

    active_scaffold :comment do |conf|
      conf.actions.exclude :search
      conf.actions.add :sunspot_search
    end

### Advanced

To customize the search behavior override the `conditions_for_solr_search` in your controller

    def conditions_for_solr_search(solr, query)
      solr.all_of do
        solr.keywords(query) unless query.blank?
        if not project.owner_id == current_user.id
          solr.with(:project_role_ids).any_of(current_user.project_role_ids)
        end
        solr.with(:project_id).equal_to(project.id)
        solr.order_by(:created_at, :desc)
      end
    end

### Note

Solr paginates your result (Sunspot sets a default of 30 results per page).
We should not try to paginate again using the database.
I had the AS `find_page` function overridden (bad) to use data from Solr for
pagination because it's pretty coupled and has no extension API.
So either we refactor `find_page` to expose an extension API,
either (currently) we have to stay in sync with upstream by migrating any changes.

### Credits

Thanks to clyfe (https://github.com/clyfe) for his initial ideas on this and for mentoring.
