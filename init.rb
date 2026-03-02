$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/lib/"
require 'issue_customer_hook'
require 'journal_patch'
require 'cust_issue_patch'
require 'cust_mail_handler_patch'
# require 'cust_attachment_patch'
Redmine::Plugin.register :redmine_helpdesk do
  name 'Redmine Helpdesk plugin'
  author 'Vignesh EsakkiMuthu'
  description 'This is a plugin for Redmine to maintain Helpdesk'
  version '0.0.1'
  url 'https://redmineconsultation.com'
end
Rails.application.config.to_prepare do
  require_dependency 'account_controller'
  require_relative 'lib/account_controller_2fa_trust_patch'

  AccountController.prepend(AccountController2faTrustPatch)
end