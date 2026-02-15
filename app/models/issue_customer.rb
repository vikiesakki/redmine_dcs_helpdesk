class IssueCustomer < ApplicationRecord
	belongs_to :issue

	def encrypt_for_url
	  str_email = "#{id}-#{issue_id}"
    encrypted = ActiveSupport::MessageEncryptor.new(Issue.enckey).encrypt_and_sign(str_email)
    Base64.urlsafe_encode64(encrypted)
  end

    def self.decrypt_url(encoded_id)
      encrypted = Base64.urlsafe_decode64(encoded_id)
      ActiveSupport::MessageEncryptor.new(Issue.enckey).decrypt_and_verify(encrypted)
    end

end