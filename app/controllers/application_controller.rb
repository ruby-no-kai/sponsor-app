class ApplicationController < ActionController::Base
  helper_method def current_sponsorship
    return @current_sponsorship if defined? @current_sponsorship
    @current_sponsorship = session[:sponsorship_id] && Sponsorship.find_by(id: session[:sponsorship_id])
  end

  def require_staff
    # TODO:
  end

  def require_sponsorship_session
    # TODO:
  end
end
