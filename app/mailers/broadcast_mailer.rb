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
    headers 'X-Auto-Response-Suppress' => 'All'
    mail(
      to: @delivery.recipient,
      cc: @delivery.recipient_ccs,
      subject: "#{subject_prefix}#{@broadcast.title}",
      reply_to: @broadcast.conference.contact_email_address,
    )
  end

  helper_method def login_url
    if @sponsorship
      token = SessionToken.create!(email: @sponsorship.contact.email, sponsorship: @sponsorship, expires_at: 2.weeks.from_now)
      url = claim_user_session_url(token)
    else
      url = new_user_session_url()
    end
    "<a href=\"#{url}\">#{url}</a>".html_safe
  end

  private

  def subject_prefix
    "[#{@broadcast.conference.name}] "
  end
end
