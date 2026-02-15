class RootController < ApplicationController
  def index
    if current_available_sponsorships&.exists?
      redirect_to user_conferences_path
      return
    end

    unless current_staff
      session.clear
      request.session_options[:skip] = true
      @cacheable = true
      response.headers['Cache-Control'] = 'public, s-maxage=3600, max-age=0'
    end

    @conferences = Conference.application_open.publicly_visible.order(id: :asc)
  end
end
