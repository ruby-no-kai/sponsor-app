class UnauthorizedTicketWarningMailer < ApplicationMailer
  def notify
    @ticket = params[:ticket]
    @sponsorship = @ticket.sponsorship
    @conference = @ticket.conference
    I18n.locale = @sponsorship.locale

    message_id_for "unauthorized-tickets/#{@ticket.id}"
    list_name 'unauthorized-tickets'
    headers 'X-Auto-Response-Suppress' => 'All'
    mail(
      to: @sponsorship.contact.email,
      cc: @sponsorship.contact.email_ccs,
      subject: make_subject(),
      reply_to: @conference.contact_email_address,
    )
  end

  private

  def subject_prefix
    "[#{@sponsorship.conference.name}] "
  end
end
