class AdminTestMailer < ApplicationMailer
  def notify
    to = params[:to]

    message_id_for "admin_test/#{Time.now.to_i}"
    mail(
      to: to,
    )
  end
end
