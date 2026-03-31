# frozen_string_literal: true

class ConferencesController < ApplicationController
  def index
    @conferences = Conference.application_open.publicly_visible.order(id: :asc)

    if @conferences.one?
      redirect_to user_conference_sponsorship_path(@conferences.first)
    elsif @conferences.empty? && current_available_sponsorships&.exists?
      redirect_to user_conference_sponsorship_path(current_available_sponsorships.first.conference)
    end
  end
end
