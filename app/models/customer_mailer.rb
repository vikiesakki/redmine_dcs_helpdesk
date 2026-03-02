class CustomerMailer < ActionMailer::Base
  
  layout 'customer_mailer'
  helper :application
  helper :issues
  helper :custom_fields
  include Rails.application.routes.url_helpers

  include Redmine::I18n
  include Roadie::Rails::Automatic

	def self.deliver_helpdesk_notification(issue_customer)
  	send_helpdesk_notification(issue_customer)
	end

  def self.deliver_emailchat_notification(issue_chat, user)
    send_emailchat_notification(issue_chat, user)
  end

  def self.deliver_helpdesk_closed(issue, customer)
    send_helpdesk_closed(issue, customer)
  end

  def self.deliver_attachment_added(journal, sender)
    send_attachment_added(journal, sender)
  end

  def self.deliver_helpdesk_notes_added(issue, journal, customer)
    send_helpdesk_notes_added(issue, journal, customer)
  end

  def self.deliver_emailchat_notes_added(issue, journal, customer)
    send_emailchat_notes_added(issue, journal, customer)
  end

  def self.deliver_emailchat_closed(issue, customer)
    send_emailchat_closed(issue, customer)
  end

  def self.deliver_noreply_notification(to)
    send_noreply_notification(to)
  end

  def send_emailchat_closed(issue, customer)
    @issue = issue
    @customer = customer
    @to = [customer.customer_email]
    # @url = url_for(:controller => 'helpdesk', :action => 'show', :enckey => @customer.encrypt_for_url)
    subj = "DCS Networks Helpdesk – Chat Ticketing Tracking #[#{@issue.id}] Ticket closed"
    mail :to => @to,
      :subject => subj
  end

  def send_noreply_notification(to)
    @to = [to]
    # @url = url_for(:controller => 'helpdesk', :action => 'show', :enckey => @customer.encrypt_for_url)
    subj = "DCS Networks Helpdesk – auto reply"
    mail :to => @to,
      :subject => subj
  end

  def send_attachment_added(journal, sender)
    @issue = journal.journalized
    @customer = sender
    @to = [sender.customer_email]
    @j = journal
    redmine_headers 'Project' => @issue.project.identifier,
                    'Issue-Tracker' => @issue.tracker.name,
                    'Issue-Id' => @issue.id,
                    'Issue-Author' => @issue.author.login
    redmine_headers 'Issue-Priority' => @issue.priority.name if @issue.priority
    # @url = url_for(:controller => 'helpdesk', :action => 'show', :enckey => @customer.encrypt_for_url)
    subj = "DCS Networks Helpdesk – Chat Ticketing Tracking #[#{@issue.id}] attachment added"
    if sender.is_a?(ChatEmail)
      subj = "DCS Networks Helpdesk – Email Ticketing Tracking #[#{@issue.id}] attachment added"
    end
    mail :to => @to,
      :subject => subj, reply_to: 'support@dcsnpl.sg'
  end

  def send_emailchat_notes_added(issue, journal, customer)
    @customer = customer
    @issue = issue
    @journal = journal
    ces = ChatEmail.where(issue_id: issue.id).pluck(:customer_email)
    @to = [customer.customer_email]
    cc = ces - [customer.customer_email]
    redmine_headers 'Project' => @issue.project.identifier,
                    'Issue-Tracker' => @issue.tracker.name,
                    'Issue-Id' => @issue.id,
                    'Issue-Author' => @issue.author.login
    redmine_headers 'Issue-Priority' => @issue.priority.name if @issue.priority
    # @url = url_for(:controller => 'helpdesk', :action => 'show', :enckey => @customer.encrypt_for_url)
    subj = "DCS Networks Helpdesk – Email Ticketing Tracking #[#{@issue.id}] notes added"
    mail :to => @to,
      :subject => subj, cc: cc, reply_to: 'support@dcsnpl.sg'
  end

  def send_emailchat_notification(issue_chat, user)
    @issue = issue_chat.issue
    redmine_headers 'Project' => @issue.project.identifier,
                    'Issue-Tracker' => @issue.tracker.name,
                    'Issue-Id' => @issue.id,
                    'Issue-Author' => @issue.author.login
    redmine_headers 'Issue-Priority' => @issue.priority.name if @issue.priority
    @customer = issue_chat
    @user = user
    # @url = url_for(:controller => 'helpdesk', :action => 'show', :enckey => @customer.encrypt_for_url)
    subj = "Subject: Thank you for your request! Your ticket number is #[#{@issue.id}]"
    mail :to => [issue_chat.customer_email], reply_to: 'support@dcsnpl.sg',
      :subject => subj
  end

  def send_helpdesk_notes_added(issue, journal, customer)
    @customer = customer
    @issue = issue
    @journal = journal
    @to = [customer.customer_email]
    @url = url_for(:controller => 'helpdesk', :action => 'show', :enckey => IssueCustomer.encrypt_for_issue(issue.id))
    subj = "DCS Networks Helpdesk – Chat Ticketing Tracking #[#{@issue.id}] notes added"
    mail :to => @to,
      :subject => subj
  end

  def send_helpdesk_closed(issue, customer)
    @issue = issue
    @customer = customer
    @to = [customer.customer_email]
    @url = url_for(:controller => 'helpdesk', :action => 'show', :enckey => @customer.encrypt_for_url)
    subj = "DCS Networks Helpdesk – Chat Ticketing Tracking #[#{@issue.id}] Ticket closed"
    mail :to => @to,
      :subject => subj
  end

  def send_helpdesk_notification(issue_customer)
    @issue = issue_customer.issue
    @customer = issue_customer
    @url = url_for(:controller => 'helpdesk', :action => 'show', :enckey => @customer.encrypt_for_url)
    subj = "DCS Networks Helpdesk – Chat Ticketing Tracking #[#{@issue.id}]"
    mail :to => [issue_customer.customer_email],
      :subject => subj
  end

  def self.default_url_options
    options = {:protocol => Setting.protocol}
    if Setting.host_name.to_s =~ /\A(https?\:\/\/)?(.+?)(\:(\d+))?(\/.+)?\z/i
      host, port, prefix = $2, $4, $5
      options.merge!(
        {
          :host => host, :port => port, :script_name => prefix
        }
      )
    else
      options[:host] = Setting.host_name
    end
    options
  end

  def mail(headers={}, &block)
    # Add a display name to the From field if Setting.mail_from does not
    # include it
    begin
      mail_from = Mail::Address.new(Setting.mail_from)
      if mail_from.display_name.blank? && mail_from.comments.blank?
        mail_from.display_name =
          @author&.logged? ? @author.name : Setting.app_title
      end
      from = mail_from.format
      list_id = "<#{mail_from.address.to_s.tr('@', '.')}>"
    rescue Mail::Field::IncompleteParseError
      # Use Setting.mail_from as it is if Mail::Address cannot parse it
      # (probably the emission address is not RFC compliant)
      from = Setting.mail_from.to_s
      list_id = "<#{from.tr('@', '.')}>"
    end

    headers.reverse_merge! 'X-Mailer' => 'Redmine',
            'X-Redmine-Host' => Setting.host_name,
            'X-Redmine-Site' => Setting.app_title,
            'X-Auto-Response-Suppress' => 'All',
            'Auto-Submitted' => 'auto-generated',
            'From' => from,
            'List-Id' => list_id

    # Replaces users with their email addresses
    # [:to, :cc, :bcc].each do |key|
    #   if headers[key].present?
    #     headers[key] = headers[key]
    #   end
    # end

    # Removes the author from the recipients and cc
    # if the author does not want to receive notifications
    # about what the author do
    if @author&.logged? && @author.pref.no_self_notified
      addresses = @author.mails
      headers[:to] -= addresses if headers[:to].is_a?(Array)
      headers[:cc] -= addresses if headers[:cc].is_a?(Array)
    end

    if @author&.logged?
      redmine_headers 'Sender' => @author.login
    end

    if @message_id_object
      headers[:message_id] = "<#{self.class.message_id_for(@message_id_object, @user)}>"
    end
    if @references_objects
      headers[:references] = @references_objects.collect {|o| "<#{self.class.references_for(o, @user)}>"}.join(' ')
    end

    if block_given?
      super headers, &block
    else
      super headers do |format|
        format.text
        format.html unless Setting.plain_text_mail?
      end
    end
  end

  private

  def message_id_for(object, user)
      token_for(object, user)
    end

  def redmine_headers(h)
    h.compact.each {|k, v| headers["X-Redmine-#{k}"] = v.to_s}
  end

  class << self
    def token_for(object, user)
      timestamp = object.send(object.respond_to?(:created_on) ? :created_on : :updated_on)
      hash = [
        "redmine",
        "#{object.class.name.demodulize.underscore}-#{object.id}",
        timestamp.utc.strftime("%Y%m%d%H%M%S")
      ]
      hash << user.id if user
      host = Setting.mail_from.to_s.strip.gsub(%r{^.*@|>}, '')
      host = "#{::Socket.gethostname}.redmine" if host.empty?
      "#{hash.join('.')}@#{host}"
    end

    # Returns a Message-Id for the given object
    def message_id_for(object, user)
      token_for(object, user)
    end

    # Returns a uniq token for a given object referenced by all notifications
    # related to this object
    def references_for(object, user)
      token_for(object, user)
    end
  end

  def message_id(object)
    @message_id_object = object
  end

  def references(object)
    @references_objects ||= []
    @references_objects << object
  end

end
