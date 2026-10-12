# typed: true
# frozen_string_literal: true

module Admin
  class SponsorshipEditingHistoriesController < Admin::ApplicationController
    def index
      conference = Conference.find_by!(slug: params[:conference_slug])
      @conference = conference
      check_staff_conference_authorization!(conference)
      sponsorship = Sponsorship.where(conference:).find(params[:sponsorship_id])
      @sponsorship = sponsorship
      @editing_histories = sponsorship.editing_histories
    end
  end
end
