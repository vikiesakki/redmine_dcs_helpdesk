module CustMailHandlerPatch
  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
    base.class_eval do
      # after_create :send_email_to_customer
      alias_method :receive_issue_reply_without_cust_patch, :receive_issue_reply
      alias_method :receive_issue_reply, :receive_issue_reply_with_cust_patch

      alias_method :dispatch_without_cust_patch, :dispatch
      alias_method :dispatch, :dispatch_with_cust_patch

      alias_method :target_project_without_cust_patch, :target_project
      alias_method :target_project, :target_project_with_cust_patch
      
    end
  end

  module ClassMethods
  end

  module InstanceMethods

    def receive_issue_reply_with_cust_patch(issue_id, from_journal=nil)
      issue = Issue.find_by(:id => issue_id)
      if issue.nil?
        CustomerMailer.deliver_noreply_notification(sender_email).deliver_now
        raise MissingContainer, "reply to nonexistant issue [##{issue_id}]"
      end
      sender_email = email.from.to_a.first.to_s.strip
      ch = ChatEmail.where(issue_id: issue.id, customer_email: sender_email)
      if issue.closed? && ch.blank?
        CustomerMailer.deliver_noreply_notification(sender_email).deliver_now
      end
      if ch.blank?
        receive_issue_reply_without_cust_patch(issue_id, from_journal)
        return
      end
      if issue.closed?
        begin
          new_issue = Issue.where(reopen_id: issue.id).first
          if new_issue.blank?
            new_issue = issue.dup
            new_issue.status_id = 1
            new_issue.reopen_id = issue.id
            new_issue.save(validate: false)
            oic = ChatEmail.where(customer_email: sender_email).first
            _h = {}
            _h[:added_str] = new_issue.author.name
            _h[:issue_id] = new_issue.id
            _h[:customer_email] = sender_email
            _h[:name] = oic.name
            ChatEmail.create(_h)
            ic = ChatEmail.where(issue_id: new_issue.id, customer_email: sender_email).first
            CustomerMailer.deliver_emailchat_notification(ic, new_issue.author).deliver_now
          end
          journal = new_issue.init_journal(user)
          text_notes = cleaned_up_text_body.split("\r\n\r\nOn")
          if text_notes.size == 1
            text_notes = cleaned_up_text_body.split("\r\n\r\nFrom: DCS")
          end
          if text_notes.size == 1
            text_notes = cleaned_up_text_body.split("\n\nOn")
          end
          journal.notes = text_notes.first
          journal.chat_id = ch.first.id
          journal.save
          return
        rescue => e
          Rails.logger.info "Error in creation of issue #{e}"
          return
        end
      end

      # Never receive emails to projects where adding issue notes is not possible
      project = issue.project

      # ignore CLI-supplied defaults for new issues
      handler_options[:issue] = {}

      journal = issue.init_journal(user)
      if from_journal && from_journal.private_notes?
        # If the received email was a reply to a private note, make the added note private
        issue.private_notes = true
      end
      issue.safe_attributes = issue_attributes_from_keywords(issue)
      issue.safe_attributes = {'custom_field_values' => custom_field_values_from_keywords(issue)}
      text_notes = cleaned_up_text_body.split("\r\n\r\nOn")
      if text_notes.size == 1
        text_notes = cleaned_up_text_body.split("\r\n\r\nFrom: DCS")
      end
      if text_notes.size == 1
        text_notes = cleaned_up_text_body.split("\n\nOn")
      end
      journal.notes = text_notes.first
      journal.chat_id = ch.first.id
      # add To and Cc as watchers before saving so the watchers can reply to Redmine
      # add_watchers(issue)
      issue.save!
      add_attachments(issue)
      logger&.info "MailHandler: issue ##{issue.id} updated by #{user}"
      journal
    end

    def dispatch_with_cust_patch
      headers = [email.in_reply_to, email.references].flatten.compact
      puts "starting the issue"
      subject = email.subject.to_s
      ticketid = subject[/#\[(\d+)\]/, 1].to_i
      puts "ticket id #{ticketid}"
      if ticketid > 0
        receive_issue_reply(ticketid)
      else
        dispatch_without_cust_patch
      end
    end

    def target_project_with_cust_patch
      # TODO: other ways to specify project:
      # * parse the email To field
      # * specific project (eg. Setting.mail_handler_target_project)
      target = get_project_from_receiver_addresses
      target ||= Project.find_by_identifier(get_keyword(:project))
      if target.nil?
        # Invalid project keyword, use the project specified as the default one
        default_project = handler_options[:issue][:project]
        if default_project.present?
          target = Project.find_by_identifier(default_project)
        end
      end
      if target.nil?
        sender_email = email.from.to_a.first.to_s.strip
        CustomerMailer.deliver_noreply_notification(sender_email).deliver_now
        raise MissingInformation, 'Unable to determine target project'
      end
      target
    end

  end
end
unless MailHandler.included_modules.include? CustMailHandlerPatch
  MailHandler.send :include, CustMailHandlerPatch
end
