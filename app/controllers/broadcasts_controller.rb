class BroadcastsController < ApplicationController
  before_action :require_sponsorship_session

  def index
    @conference = current_sponsorship.conference

    @broadcast_deliveries = BroadcastDelivery
      .includes(:broadcast)
      .where(sponsorship: current_sponsorship, broadcast: {status: :sent})
      .order(broadcast: {id: :desc})
  end

  private

  helper_method def replace_template_variables(html)
    sponsorship_url = user_conference_sponsorship_url(@conference)
    link = "<a href=\"#{sponsorship_url}\">#{sponsorship_url}</a>"
    html.gsub(/@LOGIN@|@FORM@/, link).html_safe
  end
end
