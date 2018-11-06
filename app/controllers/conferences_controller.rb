class ConferencesController < ApplicationController
  def index
    @conferences = Conference.application_open.order(id: :asc)
  end
end
