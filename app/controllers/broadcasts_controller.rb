# typed: strict
# frozen_string_literal: true

class BroadcastsController < ApplicationController
  before_action :require_sponsorship_session

  #: () -> void
  def index
    @conference = current_sponsorship.conference #: Conference?

    @broadcast_deliveries = BroadcastDelivery
      .includes(:broadcast)
      .where(sponsorship: current_sponsorship, broadcast: {status: :sent})
      .order(broadcast: {id: :desc}) #: BroadcastDelivery::PrivateRelation?
  end

  private

  #: (String) -> ActiveSupport::SafeBuffer
  helper_method def replace_template_variables(html)
    sponsorship_url = user_conference_sponsorship_url(current_conference)
    link = "<a href=\"#{sponsorship_url}\">#{sponsorship_url}</a>"
    html.gsub(/@LOGIN@|@FORM@/, link).html_safe # rubocop:disable Rails/OutputSafety
  end
end
