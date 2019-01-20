class ProcessSponsorshipEditJob < ApplicationJob
  def perform(edit)
    @sponsorship = edit.sponsorship
    @conference = @sponsorship.conference

    SlackWebhookJob.perform_now(
      text: ":pencil: <#{conference_sponsorship_url(@conference, @sponsorship)}|#{@sponsorship.name}> [#{edit.diff_summary.map{ |_| "`#{_}`" }.join(', ')}]",
      hook_name: :feed,
    )
  end
end
