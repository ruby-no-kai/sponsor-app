class SponsorshipAcceptanceJob < ApplicationJob
  def perform(sponsorship)
    token = SessionToken.create!(email: sponsorship.contact.email, expires_at: Time.zone.now + 1.year)

    SponsorshipAcceptedMailer.with(
      sponsorship: sponsorship,
      session_token: token,
    ).user_email.deliver_now

    SponsorshipAcceptedMailer.with(
      sponsorship: sponsorship,
    ).admin_email.deliver_now

    SlackWebhookJob.perform_now(
      text: ":heart: *New sponsorship* (#{sponsorship.plan_name || '*OTHER*'}): #{sponsorship.name}  <#{conference_sponsorship_url(sponsorship.conference, sponsorship)}|Open>",
    )
  end
end
