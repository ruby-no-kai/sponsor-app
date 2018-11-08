class SessionTokenMailer < ApplicationMailer
  def notify
    @token = params[:token]
    mail(
      to: @token.email,
    )
  end
end
