class Admin::DashboardController < Admin::ApplicationController
  def index
    redirect_to conferences_path
  end

  def slacktown
    SlackWebhookJob.perform_later(
      text: "This is SlackWebhookJob Test Notification invoked by #{current_staff&.login}",
    )
    render plain: "Slack Slack Slack"
  end

  def mailtown
    AdminTestMailer.with(to: params[:to]).notify.deliver_later
    render plain: "Mail Mail Mail"
  end

end
