# typed: strict
# frozen_string_literal: true

module Admin
  class SponsorEventEditingHistoriesController < Admin::ApplicationController
    #: () -> void
    def index
      conference = Conference.find_by!(slug: params[:conference_slug])
      @conference = conference #: Conference?
      check_staff_conference_authorization!(conference)
      sponsor_event = conference.sponsor_events.find(params[:sponsor_event_id])
      @sponsor_event = sponsor_event #: SponsorEvent?
      @sponsorship = sponsor_event.sponsorship #: Sponsorship?
      @editing_histories = sponsor_event.editing_histories #: SponsorEventEditingHistory::PrivateCollectionProxy?
    end
  end
end
