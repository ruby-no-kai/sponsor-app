# typed: strict
# frozen_string_literal: true

class ConferencesController < ApplicationController
  #: () -> void
  def index
    conferences = Conference.application_open.publicly_visible.order(id: :asc)
    @conferences = conferences #: Conference::PrivateRelation?

    if conferences.one?
      redirect_to user_conference_sponsorship_path(conferences.first)
    elsif conferences.empty? && (sponsorship = current_available_sponsorships&.first)
      redirect_to user_conference_sponsorship_path(sponsorship.conference)
    end
  end
end
