# typed: strict
# frozen_string_literal: true

class ProcessSponsorshipEditJob < ApplicationJob
  #: (SponsorshipEditingHistory) -> void
  def perform(edit)
    sponsorship = Must.expect(edit.sponsorship)
    conference = Must.expect(sponsorship.conference)

    staff = edit.staff
    actor = staff ? "#{staff.login} (staff)" : 'sponsor'
    SlackWebhookJob.perform_now(
      text: ":pencil: <#{conference_sponsorship_url(conference, sponsorship)}|#{sponsorship.name}> edited by #{actor} [#{edit.diff_summary.map { |s| "`#{s}`" }.join(", ")}] <#{conference_sponsorship_editing_histories_url(conference, sponsorship)}|diff>",
      hook_name: :feed,
    )

    GenerateSponsorsYamlFileJob.perform_now(conference)

    EnsureSponsorshipTitoDiscountCodeJob.perform_now(sponsorship, 'attendee')
    EnsureSponsorshipTitoDiscountCodeJob.perform_now(sponsorship, 'booth_staff')
    EnsureSponsorshipTitoDiscountCodeJob.perform_now(sponsorship, 'booth_paid')
  end
end
