class ApplicationMailer < ActionMailer::Base
  default(
    from: "#{Rails.application.config.x.org_name} Sponsorships <#{Rails.application.config.x.default_email_address}>",
    reply_to: Rails.application.config.x.default_email_reply_to,
  )

  layout 'mailer'

  before_action :add_mailer_mailgun_tag
  after_action :commit_mailgun_tag
  after_action :commit_mailgun_variables
  after_action :add_sponsorship_mailgun_tag

  private

  def message_id_for(local, reference = nil)
    headers 'Message-ID' => nil
    headers 'Message-ID' => "<#{local}@#{Rails.application.config.x.default_email_host_part}>"
    if reference
      headers 'References' => nil
      headers 'References' => "<#{reference}@#{Rails.application.config.x.default_email_host_part}>"
      headers 'In-Reply-To' => nil
      headers 'In-Reply-To' => "<#{reference}@#{Rails.application.config.x.default_email_host_part}>"
    end
  end

  def add_mailer_mailgun_tag
    tag self.class.name
    variable mailer: self.class.name
  end

  def add_sponsorship_mailgun_tag
    return unless @sponsorship && @sponsorship.is_a?(Sponsorship)
    possible_admin_address = [
      @sponsorship.conference.contact_email_address,
      Rails.application.config.x.default_email_address,
      Rails.application.config.x.default_email_reply_to,
    ]
    prefix = possible_admin_address.include?(mail.to) ? 'admin/' : ''

    tag "#{prefix}sponsorship:#{@sponsorship.id}"
    #tag "#{prefix}organization:#{@sponsorship.organization.id}"
    #tag "#{prefix}conference:#{@sponsorship.conference.id}"
  end

  def tag(*tags)
    raise "BUG: used after commit" if @mailgun_tags == :committed
    (@mailgun_tags ||= []).push(*tags)
  end

  def variable(h)
    raise "BUG: used after commit" if @mailgun_variables == :committed
    (@mailgun_variables ||= {}).merge!(h)
  end

  def commit_mailgun_tag
    (@mailgun_tags || []).uniq.each do |t|
      headers 'X-Mailgun-Tag' => t
    end
    @mailgun_tags = :committed
  end

  def commit_mailgun_variables
    raise "BUG: used after commit" if @mailgun_variables == :committed
    if @mailgun_variables
      headers 'X-Mailgun-Variables' => @mailgun_variables.to_json
    end
    @mailgun_variables = :committed
  end

  def subject_prefix
    @subject_prefix ||= "[#{Rails.application.config.x.org_name}] "
  end

  def make_subject(**params)
    "#{subject_prefix}#{default_i18n_subject(**params)}"
  end
end
