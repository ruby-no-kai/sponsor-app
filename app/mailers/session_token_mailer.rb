# typed: strict
# frozen_string_literal: true

class SessionTokenMailer < ApplicationMailer
  #: () -> void
  def notify
    token = params[:token] #: SessionToken
    @token = token #: SessionToken?
    @sponsorship = token.sponsorship # For mailgun tag

    message_id_for "session_tokens/#{token.id}"
    list_name 'login'
    mail(
      to: token.email,
      subject: make_subject,
    )
  end
end
