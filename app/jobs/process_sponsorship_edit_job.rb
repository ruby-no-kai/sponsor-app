class ProcessSponsorshipEditJob < ApplicationJob
  def perform(edit)
    @sponsorship = edit.sponsorship
    @conference = @sponsorship.conference

    actor = edit.staff ? "#{edit.staff.login} (staff)" : 'sponsor'
    SlackWebhookJob.perform_now(
      text: ":pencil: <#{conference_sponsorship_url(@conference, @sponsorship)}|#{@sponsorship.name}> edited by #{actor} [#{edit.diff_summary.map{ |_| "`#{_}`" }.join(', ')}] <#{conference_sponsorship_editing_histories_url(@conference, @sponsorship)}|diff>",
      hook_name: :feed,
    )
  end
end
