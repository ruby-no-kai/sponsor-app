class ApplicationController < ActionController::Base
  before_action :set_locale

  def set_locale
    case
    when params[:hl] 
      if I18n.available_locales.include?(params[:hl].to_sym)
        session[:hl] = params[:hl].to_sym
      else
        session.delete(:hl)
      end
    when !session[:hl] && request.headers['HTTP_CLOUDFRONT_VIEWER_COUNTRY']&.downcase == 'jp'
      session[:hl] = :ja
    end
    if session[:hl]
      I18n.locale = session[:hl]
    end
  end

  helper_method def current_staff
    return @current_staff if defined? @current_staff
    @current_staff = session[:staff_id] && Staff.find_by(id: session[:staff_id])
  end

  helper_method def current_sponsorship
    return @current_sponsorship if defined? @current_sponsorship
    # XXX: active
    @current_sponsorship = session[:sponsorship_id] && Sponsorship.active.find_by(id: session[:sponsorship_id])
  end

  def require_staff
    unless current_staff
      redirect_to new_session_path(back_to: url_for(params.to_unsafe_h.merge(only_path: true)))
    end
  end

  def require_sponsorship_session
    unless current_sponsorship
      redirect_to new_user_session_path(back_to: url_for(params.to_unsafe_h.merge(only_path: true)))
    end
  end
end
