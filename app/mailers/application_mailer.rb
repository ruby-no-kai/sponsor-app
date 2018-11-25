class ApplicationMailer < ActionMailer::Base
  default(
    from: Rails.application.config.x.default_email_address,
    reply_to: Rails.application.config.x.default_email_reply_to,
  )
  layout 'mailer'

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

  def subject_prefix
    @subject_prefix ||= "[#{Rails.application.config.x.org_name}] "
  end

  def make_subject(**params)
    "#{subject_prefix}#{default_i18n_subject(**params)}"
  end
end
