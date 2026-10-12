# typed: true
# frozen_string_literal: true

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
  after_action :commit_list_id

  default subject: -> {
    #: self as ApplicationMailer
    make_subject
  }

  # Actions set @sponsorship and @conference for the Mailgun tag and List-ID callbacks.
  def initialize
    super
    @sponsorship = nil
    @conference = nil
    @mailgun_tags = nil
    @mailgun_variables = nil
    @list_name = nil
    @subject_prefix = nil
  end

  private def message_id_for(local, reference = nil)
    headers 'Message-ID' => nil
    headers 'Message-ID' => "<#{local}@#{Rails.application.config.x.default_email_host_part}>"
    if reference
      headers 'References' => nil
      headers 'References' => "<#{reference}@#{Rails.application.config.x.default_email_host_part}>"
      headers 'In-Reply-To' => nil
      headers 'In-Reply-To' => "<#{reference}@#{Rails.application.config.x.default_email_host_part}>"
    end
  end

  private def add_mailer_mailgun_tag
    mailer_name = Must.because(self.class.name) { "mailers are named classes" }
    tag mailer_name
    variable mailer: mailer_name
  end

  private def add_sponsorship_mailgun_tag
    sponsorship = @sponsorship
    return unless sponsorship

    possible_admin_address = [
      Must.expect(sponsorship.conference).contact_email_address,
      Rails.application.config.x.default_email_address,
      Rails.application.config.x.default_email_reply_to,
    ]
    prefix = possible_admin_address.intersect?(Array(mail.to)) ? 'admin/' : ''

    tag "#{prefix}sponsorship:#{sponsorship.id}" # rubocop:disable Rails/ContentTag
    # tag "#{prefix}organization:#{@sponsorship.organization.id}"
    # tag "#{prefix}conference:#{@sponsorship.conference.id}"
  end

  private def tag(*tags)
    current = @mailgun_tags
    raise "BUG: used after commit" if current.is_a?(Symbol)

    @mailgun_tags = (current || []).concat(tags)
  end

  private def variable(h)
    current = @mailgun_variables
    raise "BUG: used after commit" if current.is_a?(Symbol)

    @mailgun_variables = (current || {}).merge!(h)
  end

  private def list_name(n)
    current = @list_name
    raise "BUG: used after commit" if current.is_a?(Symbol)

    @list_name = (current || []).push(n)
  end

  private def commit_mailgun_tag
    tags = @mailgun_tags
    raise "BUG: used after commit" if tags.is_a?(Symbol)

    (tags || []).uniq.each do |t|
      headers 'X-Mailgun-Tag' => t
    end
    @mailgun_tags = :committed
  end

  private def commit_mailgun_variables
    vars = @mailgun_variables
    raise "BUG: used after commit" if vars.is_a?(Symbol)

    headers 'X-Mailgun-Variables' => vars.to_json if vars
    @mailgun_variables = :committed
  end

  private def commit_list_id
    names = @list_name
    raise "BUG: used after commit" if names.is_a?(Symbol)

    names ||= []
    conference = @conference
    sponsorship = @sponsorship
    if conference
      names.push conference.slug
    elsif sponsorship
      names.push Must.expect(sponsorship.conference).slug
    end
    unless names.empty?
      headers 'List-ID' => "<#{names.join(".")}.#{Rails.application.config.x.default_email_host_part}>"
    end
    @list_name = :committed
  end

  private def subject_prefix
    @subject_prefix ||= "[#{Rails.application.config.x.org_name}] "
  end

  private def make_subject(**params)
    "#{subject_prefix}#{default_i18n_subject(**params)}"
  end
end
