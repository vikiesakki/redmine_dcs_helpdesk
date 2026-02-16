class HelpdeskController < ApplicationController
	layout 'customer'
	skip_before_action :verify_authenticity_token, only: [:upload, :remove]
	skip_before_action :session_expiration, :user_setup, :check_if_login_required, :check_password_change, :check_twofa_activation, except: [:journal_refresh, :email_update, :update, :destroy]
	
	helper :attachments
	helper :issues
	helper :journals
	helper :custom_fields
  	helper :issue_relations

  	def email_update
  		emails = [params[:customer]]
		emails.each do |em|
			oic = ChatEmail.where(customer_email: em).first
			if ChatEmail.where(issue_id: params[:issue_id], customer_email: em).blank?
				_h = {}
				_h[:added_str] = User.current.name
				_h[:issue_id] = params[:issue_id]
				_h[:customer_email] = em
				if oic.present?
					_h[:name] = oic.name
				else
					_h[:name] = params[:name]
				end
				ChatEmail.create(_h)
			end
			ic = ChatEmail.where(issue_id: params[:issue_id], customer_email: em).first
			CustomerMailer.deliver_emailchat_notification(ic, User.current).deliver_now
		end
		issue = Issue.find params[:issue_id]
		flash[:notice] = "Successfully created the customer email chat"
		redirect_to issue_path(issue)
  	end

	def update
		emails = params[:customer].split(',')
		emails.each do |em|
			oic = IssueCustomer.where(customer_email: em).first
			if IssueCustomer.where(issue_id: params[:issue_id], customer_email: em).blank?
				_h = {}
				_h[:added_str] = User.current.name
				_h[:issue_id] = params[:issue_id]
				_h[:customer_email] = em
				if oic.present?
					_h[:name] = oic.name
				end
				IssueCustomer.create(_h)
			end
			ic = IssueCustomer.where(issue_id: params[:issue_id], customer_email: em).first
			# CustomerMailer.deliver_helpdesk_notification(ic).deliver_now
		end
		issue = Issue.find params[:issue_id]
		flash[:notice] = "Successfully updated the customer email"
		redirect_to issue_path(issue)
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
		sp = deckey.split('-')
		issue_id = sp.first
		@ic = IssueCustomer.new
		if sp.size > 1
			id, issue_id = deckey.split('-')	
			@ic = IssueCustomer.where(customer_email: id, issue_id: issue_id).first
			if id.to_i.positive?
				@ic = IssueCustomer.where(id: id).first
			end
		end
		# id, issue_id = deckey.split('-')
		if request.post?
			@ic = IssueCustomer.where(customer_email: params[:customer_email], issue_id: issue_id).first
			if @ic.present?
				@ic.update(name: params[:name], customer_email: params[:customer_email], responded: 1, send_email: params[:email_notification])
			else
				@ic = IssueCustomer.create(name: params[:name], issue_id: issue_id, customer_email: params[:customer_email], responded: 1, send_email: params[:email_notification])
			end
		end
		@issue = Issue.find(issue_id)
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
	    id = params[:ic]
		issue_id = deckey.split('-').first
		@issue = Issue.find issue_id
		# ic = IssueCustomer.where(customer_email: id, issue_id: issue_id).first
		# if id.to_i.positive?
		ic = IssueCustomer.where(id: id).first
		# end
		if ic.blank?
			head :not_acceptable
	      	return
		end
		email = ic.customer_email
		@enckey = params[:enckey]
	    @attachment = Attachment.new(:file => raw_request_body)
	    @attachment.author = User.current
	    @attachment.container_id = issue_id
	    @attachment.container_type = "Issue"
	    @attachment.filename = params[:filename].presence || Redmine::Utils.random_hex(16)
	    @attachment.content_type = params[:content_type].presence
	    @attachment.description = "added by #{email} #{@attachment.description}"
	    saved = @attachment.save
	    notes = "attachment added #{@attachment.filename}"
	    journal = @issue.init_journal(User.current, notes)
		journal.ic_id = ic.id
		journal.save
	    respond_to do |format|
	      format.js
	    end
	end

	def refresh
		@recent_id = params[:recent_journal_id]
		deckey = IssueCustomer.decrypt_url(params[:enckey])
		issue_id = deckey.split('-').first
		id = params[:ic]
		@last_id = params[:last_journal_id]
		@ic = IssueCustomer.where(customer_email: id, issue_id: issue_id).first
		if id.to_i.positive?
			@ic = IssueCustomer.where(id: id).first
		end
		@issue = @ic.issue
		@journals = @issue.journals
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

	def close
		deckey = IssueCustomer.decrypt_url(params[:enckey])
		id = params[:ic]
		issue_id = deckey.split('-').first
		@ic = IssueCustomer.where(id: id).first
		if id.to_i.positive?
			@ic = IssueCustomer.where(id: id).first
		end
		@issue = @ic.issue
		if @ic.blank? || @issue.blank?
			flash[:error] = "Invalid request"
		else
			flash[:notice] = "Successfully updated"
		end
		
		if params[:msg].present?
			Journal.create(journalized_id: @issue.id,                                        
 						   journalized_type: "Issue",                                    
 						   user_id: User.current.id,
 						   ic_id: @ic.id,                                              
 						   notes: params[:msg])
		end
		notes = "Ticket closed by customer"
		closed_status = IssueStatus.where(is_closed: true).first
		@issue.update(status_id: closed_status.id)
		j = @issue.init_journal(User.current, notes)
		j.ic_id = @ic.id
		j.save
		ics = IssueCustomer.where(issue_id: @issue.id)
		ics.each do |ic|
			CustomerMailer.deliver_helpdesk_closed(@issue, ic).deliver_now
		end
		@journals = @issue.journals
		render :show
		# redirect_to helpdesk_show_path(params[:enckey])
	end

	def journal_refresh
		@last_id = params[:last_journal_id]
		@recent_id = params[:recent_journal_id]
		@issue = Issue.find params[:issue_id]
		@journal = @issue.journals.last
		respond_to do |format|
	      format.js
	    end
	end

	def add_notes
		deckey = IssueCustomer.decrypt_url(params[:enckey])
		id = params[:ic]
		issue_id = deckey.split('-')
		@ic = IssueCustomer.where(customer_email: id, issue_id: issue_id).first
		if id.to_i.positive?
			@ic = IssueCustomer.where(id: id).first
		end
		email = @ic.customer_email
		@issue = @ic.issue
		emails = []
		customer_name = params[:customer_name]
		ic = IssueCustomer.where(customer_email: email).update(name: customer_name)
		if params[:email].present?
			emails.each do |em|
				oic = IssueCustomer.where(customer_email: em).first
				if IssueCustomer.where(issue_id: issue_id, customer_email: em).blank?
					_h = {}
					_h[:added_str] = User.current.name
					_h[:issue_id] = issue_id
					_h[:customer_email] = em
					if oic.present?
						_h[:name] = oic.name
					end
					IssueCustomer.create(_h)
				end
				ic = IssueCustomer.where(issue_id: issue_id, customer_email: em).first
				CustomerMailer.deliver_helpdesk_notification(ic).deliver_now
			end
			flash[:notice] = "Invite sent successfully"
		else
			if params[:notes].present?
				notes = "#{params[:notes]}"
				journal = @issue.init_journal(User.current, notes)
				journal.ic_id = @ic.id
				journal.save
				flash[:notice] = "Added successfully"
			else
				flash[:error] = "notes cannot be blank"
			end
		end
		# @issue = Issue.find(issue_id)
		@journals = @issue.journals
		render :show
		# redirect_to helpdesk_show_path(params[:enckey])
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