class ProcessSponsorEventEditJob < ApplicationJob
  include Rails.application.routes.url_helpers

  def perform(edit)
    @sponsor_event = edit.sponsor_event
    @sponsorship = @sponsor_event.sponsorship
    @conference = @sponsor_event.conference

    is_new_submission = edit.id == @sponsor_event.editing_histories.minimum(:id)
    actor = edit.staff ? "#{edit.staff.login} (staff)" : 'sponsor'
    action = is_new_submission ? 'filed' : 'edited'
    SlackWebhookJob.perform_now(
      {
        text: ":calendar: <#{conference_sponsor_event_url(@conference, @sponsor_event)}|#{@sponsor_event.title}> (<#{conference_sponsorship_url(@conference, @sponsorship)}|#{@sponsorship.name}>): #{action} by #{actor} [#{edit.diff_summary.map { |_| "`#{_}`" }.join(', ')}] <#{conference_sponsor_event_editing_histories_url(@conference, @sponsor_event)}|diff>",
      },
      hook_name: :feed,
    )

    should_update_yaml = @sponsor_event.accepted? || status_changed_in_edit?(edit)
    GenerateSponsorsYamlFileJob.perform_now(@conference) if should_update_yaml

    if should_push_event_asset?(edit)
      PushEventAssetFileJob.perform_later(edit)
    end
  end

  private

  def status_changed_in_edit?(edit)
    return false unless edit.diff

    edit.diff.any? { |change| change[1] == 'status' }
  end

  def should_push_event_asset?(edit)
    return false unless @sponsor_event.accepted?
    return false unless @sponsor_event.asset_file

    return true if status_changed_to_accepted_in_edit?(edit)
    return false unless edit.diff

    edit.diff.any? do |change|
      (change[1] == 'asset_file_id' || change[1] == 'asset_file_checksum_sha256') &&
        change.last.present?
    end
  end

  def status_changed_to_accepted_in_edit?(edit)
    return false unless edit.diff
    edit.diff.any? { |change| change[1] == 'status' && change.last == 'accepted' }
  end
end
