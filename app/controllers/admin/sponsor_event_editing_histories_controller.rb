# typed: true
# frozen_string_literal: true

module Admin
  class SponsorEventEditingHistoriesController < Admin::ApplicationController
    def index
      conference = Conference.find_by!(slug: params[:conference_slug])
      @conference = conference
      check_staff_conference_authorization!(conference)
      sponsor_event = conference.sponsor_events.find(params[:sponsor_event_id])
      @sponsor_event = sponsor_event
      @sponsorship = sponsor_event.sponsorship
      @editing_histories = sponsor_event.editing_histories
    end
  end
end
