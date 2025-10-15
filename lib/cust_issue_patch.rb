module CustIssuePatch
  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
    base.class_eval do
      before_save :send_all_to_customer
    end
  end

  module ClassMethods
  end

  module InstanceMethods
    def send_all_to_customer
      return unless status_changed?
      return unless closed?
      return if id.blank?
      ics = IssueCustomer.where(issue_id: id)
      ces = ChatEmail.where(issue_id: id)
      return if ics.blank? && ces.blank?
      ics.each do |ic|
        CustomerMailer.deliver_helpdesk_closed(self, ic).deliver_now
      end
      ces.each do |ce|
        CustomerMailer.deliver_emailchat_closed(self, ce).deliver_now
      end
    end



  end
end
unless Issue.included_modules.include? CustIssuePatch
  Issue.send :include, CustIssuePatch
end
