class BroadcastMailer < ApplicationMailer
  def announce
    @delivery = params[:delivery]
    @broadcast = @delivery.broadcast
    @sponsorship = @delivery.sponsorship
    @conference = @broadcast.conference

    message_id_for "broadcasts/#{@broadcast.id}/deliveries/#{@delivery.id}"
    tag "broadcast:#{@broadcast.id}"
    variable broadcast_id: @broadcast.id, delivery_id: @delivery.id
    list_name 'broadcast'
    mail(
      to: @delivery.recipient,
      subject: "#{subject_prefix}#{@broadcast.title}",
      reply_to: @broadcast.conference.contact_email_address,
    )
  end

  private

  def subject_prefix
    "[#{@broadcast.conference.name}] "
  end
end
