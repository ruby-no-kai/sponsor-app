class ApplicationMailer < ActionMailer::Base
  default from: Rails.application.config.x.default_email_address
  layout 'mailer'

  private

  def message_id_for(local)
    "#{local}@#{Rails.application.config.x.default_email_host_part}"
  end
end
