class TicketRetrievalMailer < ApplicationMailer
  def notify
    @ticket = params[:ticket]
    @sponsorship = @ticket.sponsorship
    @conference = @ticket.conference

    @ticket_link = retrieve_user_conference_ticket_url(@conference, handle: @ticket.handle)

    message_id_for "tickets/#{@ticket.id}"
    list_name 'tickets'
    headers 'X-Auto-Response-Suppress' => 'All'
    mail(
      to: @ticket.email,
      subject: make_subject(),
      reply_to: @conference.contact_email_address,
    )
  end

  private

  def subject_prefix
    "[#{@sponsorship.conference.name}] "
  end
end
