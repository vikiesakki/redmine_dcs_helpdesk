module JournalPatch
  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
    base.class_eval do
      after_create :send_email_to_customer
    end
  end

  module ClassMethods
  end

  module InstanceMethods
    def send_email_to_customer
      return unless journalized_type == 'Issue'
      return if user.is_a?(AnonymousUser)
      return if IssueCustomer.where(issue_id: journalized_id).blank?  && ChatEmail.where(issue_id: journalized_id).blank?
      if details.pluck(:property).include?("attachment")
        # dd = details.select{|d| d.property == 'attachment' }
        ics = IssueCustomer.where(issue_id: journalized_id)
        ics.each do |ic|
          CustomerMailer.deliver_attachment_added(self, ic).deliver_now
        end
        ces = ChatEmail.where(issue_id: journalized_id)
        ces.each do |ce|
          CustomerMailer.deliver_attachment_added(self, ce).deliver_now
        end
        return
      end
      if notes.present?
        ics = IssueCustomer.where(issue_id: journalized_id)
        ics.each do |ic|
          CustomerMailer.deliver_helpdesk_notes_added(journalized, self, ic).deliver_now
        end
        ces = ChatEmail.where(issue_id: journalized_id)
        # ces.each do |ce|
        if ces.present?
          CustomerMailer.deliver_emailchat_notes_added(journalized, self, ces.first).deliver_now
        end
      end
    end

  end
end
unless Journal.included_modules.include? JournalPatch
  Journal.send :include, JournalPatch
end
