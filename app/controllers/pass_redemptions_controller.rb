# typed: strict
# frozen_string_literal: true

class PassRedemptionsController < ApplicationController
  before_action :require_sponsorship_session

  #: () -> void
  def index
    sponsorship = current_sponsorship
    conference = Must.expect(sponsorship.conference)
    @sponsorship = sponsorship #: Sponsorship?
    @conference = conference #: Conference?
    raise ActiveRecord::RecordNotFound unless conference.distributing_ticket? && conference.tito_slug.present?

    @pass_redemptions = PassRedemption.list_for_sponsorship(sponsorship) #: PassRedemption::Collection?
    # @pass_redemptions = PassRedemption.list_for_source_id('rubykaigi/2025', 'sorah')
  end
end
