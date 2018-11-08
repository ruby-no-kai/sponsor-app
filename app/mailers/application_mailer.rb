class ApplicationMailer < ActionMailer::Base
  default from: Rails.application.config.x.default_email_address
  layout 'mailer'
end
