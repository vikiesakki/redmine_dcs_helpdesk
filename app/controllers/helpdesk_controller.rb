class HelpdeskController < ApplicationController
	layout 'customer'
	skip_before_action :verify_authenticity_token, only: [:upload, :remove]
	skip_before_action :session_expiration, :user_setup, :check_if_login_required, :check_password_change, :check_twofa_activation, except: [:update, :destroy]
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

	def upload
	    # Make sure that API users get used to set this content type
	    # as it won't trigger Rails' automatic parsing of the request body for parameters
	    unless request.media_type == 'application/octet-stream'
	      head :not_acceptable
	      return
	    end
	    deckey = IssueCustomer.decrypt_url(params[:enckey])
		email, issue_id = deckey.split('-')
		ic = IssueCustomer.where(issue_id: issue_id, customer_email: email).first
		if ic.blank?
			head :not_acceptable
	      	return
		end
		@enckey = params[:enckey]
	    @attachment = Attachment.new(:file => raw_request_body)
	    @attachment.author = User.current
	    @attachment.container_id = issue_id
	    @attachment.container_type = "Issue"
	    @attachment.filename = params[:filename].presence || Redmine::Utils.random_hex(16)
	    @attachment.content_type = params[:content_type].presence
	    @attachment.description = "added by #{email} #{@attachment.description}"
	    saved = @attachment.save

	    respond_to do |format|
	      format.js
	    end
	end

	def remove
		@attachment = Attachment.find params[:id]
		@attachment.delete
		respond_to do |format|
	      format.js
	    end
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

	private

	def raw_request_body
	    if request.body.respond_to?(:size)
	      request.body
	    else
	      request.raw_post
	    end
  	end
end