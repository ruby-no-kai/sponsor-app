# typed: strict
# frozen_string_literal: true

class AdminTestMailer < ApplicationMailer
  #: () -> void
  def notify
    to = params[:to] #: String?

    message_id_for "admin_test/#{Time.now.to_i}"
    mail(
      to: to,
    )
  end
end
