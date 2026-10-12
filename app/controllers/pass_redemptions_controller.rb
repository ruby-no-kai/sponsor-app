# typed: true
# frozen_string_literal: true

class PassRedemptionsController < ApplicationController
  before_action :require_sponsorship_session

  def index
    sponsorship = current_sponsorship
    conference = Must.expect(sponsorship.conference)
    @sponsorship = sponsorship
    @conference = conference
    raise ActiveRecord::RecordNotFound unless conference.distributing_ticket? && conference.tito_slug.present?

    @pass_redemptions = PassRedemption.list_for_sponsorship(sponsorship)
    # @pass_redemptions = PassRedemption.list_for_source_id('rubykaigi/2025', 'sorah')
  end
end
