class ApplicationMailer < ActionMailer::Base
  default from: Rails.application.config.x.default_email_address
  layout 'mailer'

  private

  def message_id_for(local)
    headers 'Message-ID' => nil
    headers 'Message-ID' => "#{local}@#{Rails.application.config.x.default_email_host_part}"
  end

  def subject_prefix
    @subject_prefix ||= "[#{Rails.application.config.x.org_name}] "
  end

  def make_subject(**params)
    "#{subject_prefix}#{default_i18n_subject(**params)}"
  end
end
