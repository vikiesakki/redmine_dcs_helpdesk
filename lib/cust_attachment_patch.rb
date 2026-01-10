module CustAttachmentPatch
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
      if author.is_a?(User) && container_id_changed? && container.is_a?(Issue) && container_id_was.nil?
      ics = IssueCustomer.where(issue_id: container_id)
      ces = ChatEmail.where(issue_id: container_id)
      return if ics.blank? && ces.blank?
      ics.each do |ic|
        CustomerMailer.deliver_attachment_added(self, ic).deliver_now
      end
      ces.each do |ce|
        CustomerMailer.deliver_attachment_added(self, ce).deliver_now
      end
      end
    end



  end
end
unless Attachment.included_modules.include? CustAttachmentPatch
  Attachment.send :include, CustAttachmentPatch
end
