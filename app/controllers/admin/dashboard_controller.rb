# typed: strict
# frozen_string_literal: true

module Admin
  class DashboardController < Admin::ApplicationController
    class Boom < StandardError; end

    before_action :require_unrestricted_staff, only: %i[slacktown mailtown errortown]

    #: () -> void
    def index
      redirect_to conferences_path
    end

    #: () -> void
    def slacktown
      SlackWebhookJob.perform_later(
        {text: "This is SlackWebhookJob Test Notification invoked by #{current_staff.login}"},
      )
      render plain: "Slack Slack Slack"
    end

    #: () -> void
    def mailtown
      AdminTestMailer.with(to: params[:to]).notify.deliver_later
      render plain: "Mail Mail Mail"
    end

    #: () -> void
    def errortown
      request_id = request.request_id
      ErrorTownJob.perform_later(request_id)
      raise Boom, "boom! #{request_id}"
    end
  end
end
