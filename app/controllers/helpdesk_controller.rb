class HelpdeskController < ApplicationController
	layout 'customer'
	skip_before_action :session_expiration, :user_setup, :check_if_login_required, :check_password_change, :check_twofa_activation, except: :update
	def update
		if IssueCustomer.where(issue_id: params[:issue_id], customer_email: params[:customer]).blank?
			IssueCustomer.create(added_str: User.current.name, issue_id: params[:issue_id], customer_email: params[:customer])
		end
		ic = IssueCustomer.where(issue_id: params[:issue_id], customer_email: params[:customer]).first
		CustomerMailer.deliver_helpdesk_notification(ic).deliver_now
		flash[:notice] = "Successfully updated the customer email"
		redirect_to issue_path(ic.issue)
	end

	def destroy
		id = params[:id]
		issue_id = params[:issue_id]
		ic = IssueCustomer.find(id)
		ic.destroy
		flash[:notice] = "Successfully deleted the customer email"
		redirect_to issue_path(ic.issue)
	end

	def show
		deckey = IssueCustomer.decrypt_url(params[:enckey])
		email, issue_id = deckey.split('-')
		@ic = IssueCustomer.where(issue_id: issue_id, customer_email: email).first
		@issue = @ic.issue
		@journals = @issue.journals
	end

	def add_notes
		deckey = IssueCustomer.decrypt_url(params[:enckey])
		email, issue_id = deckey.split('-')
		@ic = IssueCustomer.where(issue_id: issue_id, customer_email: email).first
		@issue = @ic.issue
		if params[:email].present?
			if IssueCustomer.where(issue_id: issue_id, customer_email: params[:email]).blank?
				IssueCustomer.create(added_str: email, issue_id: issue_id, customer_email: params[:email])
			end
			flash[:notice] = "Invite sent successfully"
			ic = IssueCustomer.where(issue_id: issue_id, customer_email: params[:email]).first
			CustomerMailer.deliver_helpdesk_notification(ic).deliver_now
		else
			if params[:notes].present?
				notes = "Added by #{email} \n #{params[:notes]}"
				journal = @issue.init_journal(User.current, notes)
				journal.save
				flash[:notice] = "Added successfully"
			else
				flash[:error] = "notes cannot be blank"
			end
		end
		redirect_to helpdesk_show_path(params[:enckey])
	end
end