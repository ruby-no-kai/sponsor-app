# frozen_string_literal: true

module Admin
  class SponsorshipEditingHistoriesController < Admin::ApplicationController
    def index
      @conference = Conference.find_by!(slug: params[:conference_slug])
      check_staff_conference_authorization!(@conference)
      @sponsorship = Sponsorship.where(conference: @conference).find(params[:sponsorship_id])
      @editing_histories = @sponsorship.editing_histories
    end
  end
end
