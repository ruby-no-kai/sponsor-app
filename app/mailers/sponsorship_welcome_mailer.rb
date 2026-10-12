# typed: strict
# frozen_string_literal: true

class SponsorshipWelcomeMailer < ApplicationMailer
  #: () -> void
  def user_email
    sponsorship = params[:sponsorship] #: Sponsorship
    session_token = params[:session_token] #: SessionToken
    conference = Must.expect(sponsorship.conference)
    contact = Must.because(sponsorship.contact) { "sponsorships validate the presence of their contact" }
    @sponsorship = sponsorship
    @session_token = session_token #: SessionToken?
    @conference_name = conference.name #: String?

    @sponsor_org_name = contact.organization #: String?
    @sponsor_contact_name = contact.name #: String?

    @login_link = claim_user_session_url(session_token) #: String?
    @login_link_expiry = session_token.expires_at #: ActiveSupport::TimeWithZone?

    @email = conference.contact_email_address #: String?
    @team_name = conference.name #: String?

    message_id_for "sponsorships/#{sponsorship.id}", "admin/sponsorships/#{sponsorship.id}"
    list_name 'welcome'
    mail(
      to: contact.email,
      cc: contact.email_ccs,
      subject: make_subject,
      reply_to: @email,
    )
  end

  #: () -> void
  def admin_email
    sponsorship = params[:sponsorship] #: Sponsorship
    contact = Must.because(sponsorship.contact) { "sponsorships validate the presence of their contact" }
    @sponsorship = sponsorship

    @sponsor_name = contact.organization #: String?
    @sponsor_org_name = sponsorship.name
    @sponsor_contact_name = contact.name
    @sponsor_contact_email = contact.email #: String?

    @link = conference_sponsorship_url(sponsorship.conference, sponsorship) #: String?

    message_id_for "admin/sponsorships/#{sponsorship.id}"
    mail(
      to: Must.expect(sponsorship.conference).contact_email_address,
      subject: make_subject(name: @sponsor_name),
      reply_to: @sponsor_contact_email,
    )
  end

  #: () -> String
  private def subject_prefix
    "[#{Must.expect(sponsorship.conference).name}] "
  end

  #: () -> Sponsorship
  private def sponsorship = Must.because(@sponsorship) { "user_email and admin_email set the sponsorship" }
end
