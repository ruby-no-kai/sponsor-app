# typed: strict
# frozen_string_literal: true

class BroadcastMailer < ApplicationMailer
  #: () -> void
  def announce
    delivery = params[:delivery] #: BroadcastDelivery
    broadcast = Must.expect(delivery.broadcast)
    conference = Must.expect(broadcast.conference)
    @delivery = delivery #: BroadcastDelivery?
    @broadcast = broadcast #: Broadcast?
    @sponsorship = delivery.sponsorship
    @conference = conference

    message_id_for "broadcasts/#{broadcast.id}/deliveries/#{delivery.id}"
    tag "broadcast:#{broadcast.id}" # rubocop:disable Rails/ContentTag
    variable broadcast_id: broadcast.id, delivery_id: delivery.id
    list_name 'broadcast'
    headers 'X-Auto-Response-Suppress' => 'All'
    mail(
      to: delivery.recipient,
      cc: delivery.recipient_ccs,
      subject: "#{subject_prefix}#{broadcast.title}",
      reply_to: conference.contact_email_address,
    )
  end

  #: () -> ActiveSupport::SafeBuffer
  helper_method def form_url
    path = Addressable::URI.parse(new_user_conference_sponsorship_url(@conference)).request_uri
    login_url(back_to: path)
  end

  #: (**String?) -> ActiveSupport::SafeBuffer
  helper_method def login_url(**additional_params)
    sponsorship = @sponsorship
    if sponsorship
      contact = Must.because(sponsorship.contact) { "sponsorships validate the presence of their contact" }
      token = SessionToken.create!(email: contact.email, sponsorship: sponsorship, expires_at: 2.weeks.from_now)
      url = claim_user_session_url(token, **additional_params)
    else
      url = new_user_session_url(**additional_params)
    end
    "<a href=\"#{url}\">#{url}</a>".html_safe # rubocop:disable Rails/OutputSafety
  end

  #: () -> String
  private def subject_prefix
    "[#{Must.expect(broadcast.conference).name}] "
  end

  #: () -> Broadcast
  private def broadcast = Must.because(@broadcast) { "announce sets the broadcast" }
end
