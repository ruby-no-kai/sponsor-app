class SponsorshipAcceptanceJob < ApplicationJob
  def perform(sponsorship)
    token = SessionToken.create!(email: sponsorship.contact.email, expires_at: Time.zone.now + 1.year)

    SponsorshipAcceptedMailer.with(
      sponsorship: sponsorship,
      session_token: token,
    ).user_email.deliver_now

    Admin::SponsorshipAcceptedMailer.with(
      sponsorship: sponsorship,
    ).admin_email.deliver_now
  end
end
