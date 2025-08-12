class IssueCustomerHook < Redmine::Hook::ViewListener
	render_on :view_issues_show_description_bottom,
                partial: 'hooks/issue_customer'
end