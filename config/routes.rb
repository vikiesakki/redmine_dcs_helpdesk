# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
match 'helpdesk/:issue_id/update', as: 'helpdesk_update', to: "helpdesk#update", via: [:post, :get]
match 'helpdesk/:issue_id/destroy/:id', as: 'helpdesk_destroy', to: "helpdesk#destroy", via: [:delete]
match 'helpdesk/:enckey', as: 'helpdesk_show', to: "helpdesk#show", via: [:post, :get]
match 'helpdesk/:enckey/add-notes', as: 'helpdesk_add_notes', to: "helpdesk#add_notes", via: [:post, :get]