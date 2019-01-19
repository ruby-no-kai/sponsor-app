class Webhooks::MailgunController < ApplicationController
  skip_before_action :verify_authenticity_token

  def webhook
    p params
    render status: 200, plain: 'OK'
  end
end
