class ConferencesController < ApplicationController
  def index
    @conferences = Conference.application_open.publicly_visible.order(id: :asc)

    if @conferences.one?
      redirect_to user_conference_sponsorship_path(@conferences.first)
    end
  end
end
