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
      
    end
  end

  module ClassMethods
  end

  module InstanceMethods

    def receive_issue_reply_with_cust_patch(issue_id, from_journal=nil)
      issue = Issue.find_by(:id => issue_id)
      if issue.nil?
        raise MissingContainer, "reply to nonexistant issue [##{issue_id}]"
      end
      sender_email = email.from.to_a.first.to_s.strip
      ch = ChatEmail.where(issue_id: issue.id, email: sender_email)
      if ch.blank?
        receive_issue_reply_without_cust_patch(issue_id, from_journal)
        return
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
      elsif headers.detect {|h| h.to_s =~ MESSAGE_ID_RE}
        klass, object_id = $1, $2.to_i
        method_name = "receive_#{klass}_reply"
        if self.class.private_instance_methods.collect(&:to_s).include?(method_name)
          send method_name, object_id
        else
          puts "Ignoring it"
          # ignoring it
        end
      elsif m = subject.match(ISSUE_REPLY_SUBJECT_RE)
        receive_issue_reply(m[1].to_i)
      elsif m = subject.match(MESSAGE_REPLY_SUBJECT_RE)
        receive_message_reply(m[1].to_i)
      else
        dispatch_to_default
      end
    rescue ActiveRecord::RecordInvalid => e
      # TODO: send a email to the user
      logger&.error "MailHandler: #{e.message}"
      false
    rescue MissingInformation => e
      logger&.error "MailHandler: missing information from #{user}: #{e.message}"
      false
    rescue MissingContainer => e
      logger&.error "MailHandler: reply to nonexistant object from #{user}: #{e.message}"
      false
    rescue UnauthorizedAction => e
      logger&.error "MailHandler: unauthorized attempt from #{user}: #{e.message}"
      false
    end


  end
end
unless MailHandler.included_modules.include? CustMailHandlerPatch
  MailHandler.send :include, CustMailHandlerPatch
end
