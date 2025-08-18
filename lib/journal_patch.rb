module JournalPatch
  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
    base.class_eval do
      after_save :send_email_to_customer
    end
  end

  module ClassMethods
  end

  module InstanceMethods
    def send_email_to_customer
      return unless journalized_type == 'Issue'
      return if IssueCustomer.where(issue_id: journalized_id).blank?
      unless notes.present? || user.is_a?(AnonymousUser)
        ics = IssueCustomer.where(issue_id: journalized_id)
        ics.each do |ic|
          CustomerMailer.deliver_helpdesk_notes_added(journalized, self, ic)
        end
      end
    end



  end
end
unless Journal.included_modules.include? JournalPatch
  Journal.send :include, JournalPatch
end
