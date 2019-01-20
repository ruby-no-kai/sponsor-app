class SessionTokenMailer < ApplicationMailer
  def notify
    @token = params[:token]
    @sponsorship = @token.sponsorship # For mailgun tag

    message_id_for "session_tokens/#{@token.id}"
    list_name 'login'
    mail(
      to: @token.email,
      subject: make_subject(),
    )
  end
end
