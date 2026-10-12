# typed: strict
# frozen_string_literal: true

class SponsorshipWelcomeJob < ApplicationJob
  #: (Sponsorship) -> void
  def perform(sponsorship)
    contact = Must.because(sponsorship.contact) { "sponsorships validate the presence of their contact" }
    token = SessionToken.create!(email: contact.email, expires_at: Time.zone.now + 1.year)

    SponsorshipWelcomeMailer.with(
      sponsorship: sponsorship,
      session_token: token,
    ).user_email.deliver_now

    SponsorshipWelcomeMailer.with(
      sponsorship: sponsorship,
    ).admin_email.deliver_now

    SlackWebhookJob.perform_now(
      {text: ":tamago: *New sponsorship* (#{sponsorship.plan_name || "*OTHER*"}): #{sponsorship.name}  <#{conference_sponsorship_url(sponsorship.conference, sponsorship)}|Open>"},
    )

    EnsureSponsorshipTitoDiscountCodeJob.perform_later(sponsorship, 'attendee')
    GenerateSponsorsYamlFileJob.perform_later(sponsorship.conference)

    asset_file = Must.because(sponsorship.asset_file) { "sponsorships validate the presence of their asset file" }
    BackfillSponsorshipAssetFileChecksumJob.perform_later(asset_file) if asset_file.checksum_sha256 == '-'
  end
end
