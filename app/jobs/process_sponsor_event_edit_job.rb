# typed: strict
# frozen_string_literal: true

class ProcessSponsorEventEditJob < ApplicationJob
  #: (SponsorEventEditingHistory) -> void
  def perform(edit)
    sponsor_event = Must.expect(edit.sponsor_event)
    sponsorship = Must.expect(sponsor_event.sponsorship)
    conference = Must.expect(sponsor_event.conference)
    @sponsor_event = sponsor_event #: SponsorEvent?

    is_new_submission = edit.id == sponsor_event.editing_histories.minimum(:id)
    staff = edit.staff
    actor = staff ? "#{staff.login} (staff)" : 'sponsor'
    action = is_new_submission ? 'filed' : 'edited'
    SlackWebhookJob.perform_now(
      text: ":calendar: <#{conference_sponsor_event_url(conference, sponsor_event)}|#{sponsor_event.title}> (<#{conference_sponsorship_url(conference, sponsorship)}|#{sponsorship.name}>): #{action} by #{actor} [#{edit.diff_summary.map { |s| "`#{s}`" }.join(", ")}] <#{conference_sponsor_event_editing_histories_url(conference, sponsor_event)}|diff>",
      hook_name: :feed,
    )

    should_update_yaml = sponsor_event.accepted? || status_changed_in_edit?(edit)
    GenerateSponsorsYamlFileJob.perform_now(conference) if should_update_yaml

    if should_push_event_asset?(edit)
      PushEventAssetFileJob.perform_later(edit)
    end
  end

  #: (SponsorEventEditingHistory) -> bool
  private def status_changed_in_edit?(edit)
    edit.diff_changes.any? { it.path == 'status' }
  end

  #: (SponsorEventEditingHistory) -> bool
  private def should_push_event_asset?(edit)
    return false unless sponsor_event.accepted?
    return false unless sponsor_event.asset_file

    return true if status_changed_to_accepted_in_edit?(edit)

    edit.diff_changes.any? do |change|
      (change.path == 'asset_file_id' || change.path == 'asset_file_checksum_sha256') &&
        change.new_value? && change.new_value.present?
    end
  end

  #: (SponsorEventEditingHistory) -> bool
  private def status_changed_to_accepted_in_edit?(edit)
    edit.diff_changes.any? { |change| change.path == 'status' && change.new_value? && change.new_value == 'accepted' }
  end

  #: () -> SponsorEvent
  private def sponsor_event = Must.because(@sponsor_event) { "perform sets the sponsor event" }
end
