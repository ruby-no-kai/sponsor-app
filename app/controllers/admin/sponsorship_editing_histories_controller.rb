# typed: strict
# frozen_string_literal: true

module Admin
  class SponsorshipEditingHistoriesController < Admin::ApplicationController
    #: () -> void
    def index
      conference = Conference.find_by!(slug: params[:conference_slug])
      @conference = conference #: Conference?
      check_staff_conference_authorization!(conference)
      sponsorship = Sponsorship.where(conference:).find(params[:sponsorship_id])
      @sponsorship = sponsorship #: Sponsorship?
      @editing_histories = sponsorship.editing_histories #: SponsorshipEditingHistory::PrivateCollectionProxy?
    end
  end
end
