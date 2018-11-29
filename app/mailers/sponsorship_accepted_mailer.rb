class SponsorshipAcceptedMailer < ApplicationMailer
  def user_email
    @sponsorship = params[:sponsorship]
    @session_token = params[:session_token]

    @sponsor_org_name = @sponsorship.contact.organization
    @sponsor_contact_name = @sponsorship.contact.name

    @login_link = claim_user_session_url(@session_token)
    @login_link_expiry = @session_token.expires_at

    @email = @sponsorship.conference.contact_email_address
    @team_name = @sponsorship.conference.name

    message_id_for "sponsorships/#{@sponsorship.id}", "admin/sponsorships/#{@sponsorship.id}"
    mail(
      to: @sponsorship.contact.email,
      subject: make_subject(),
      reply_to: @email,
    )
  end

  def admin_email
    @sponsorship = params[:sponsorship]

    @sponsor_name = @sponsorship.contact.organization
    @sponsor_org_name = @sponsorship.name
    @sponsor_contact_name = @sponsorship.contact.name
    @sponsor_contact_email = @sponsorship.contact.email

    @link = conference_sponsorship_url(@sponsorship.conference, @sponsorship)

    message_id_for "admin/sponsorships/#{@sponsorship.id}"
    mail(
      to: @sponsorship.conference.contact_email_address,
      subject: make_subject(name: @sponsor_name),
      reply_to: @sponsor_contact_email,
    )
  end

  private

  def subject_prefix
    "[#{@sponsorship.conference.name}] "
  end
end
