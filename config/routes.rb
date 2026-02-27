# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
match 'helpdesk/:issue_id/update', as: 'helpdesk_update', to: "helpdesk#update", via: [:post, :get]
match 'helpdesk/:issue_id/email_update', as: 'helpdesk_email_update', to: "helpdesk#email_update", via: [:post, :get]
match 'helpdesk/:issue_id/destroy/:id', as: 'helpdesk_destroy', to: "helpdesk#destroy", via: [:delete]
match 'helpdesk/:enckey', as: 'helpdesk_show', to: "helpdesk#show", via: [:post, :get]
match 'helpdesk/:enckey/close', as: 'helpdesk_close', to: "helpdesk#close", via: [:post, :get]
match 'helpdesk/:enckey/refresh', as: 'helpdesk_refresh', to: "helpdesk#refresh", via: [:post, :get]
match 'helpdesk/:enckey/add-notes', as: 'helpdesk_add_notes', to: "helpdesk#add_notes", via: [:post, :get]
match 'helpdesk/:enckey/upload/:ic(.:format)', as: 'helpdesk_upload', to: "helpdesk#upload", via: [:post]
match 'helpdesk/:enckey/remove/:id', as: 'helpdesk_remove', to: "helpdesk#remove", via: [:delete]
match 'journal/:issue_id/refresh', as: 'journal_refresh', to: "helpdesk#journal_refresh", via: [:post, :get]