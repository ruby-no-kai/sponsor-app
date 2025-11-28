class ApplicationController < ActionController::Base
  before_action :set_locale
  before_action :populate_sentry_scope

  private

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
    return nil unless params[:conference_slug]
    return nil unless session[:sponsorship_ids]

    @current_sponsorship = Sponsorship.where(id: session[:sponsorship_ids])
      .joins(:conference)
      .merge(Conference.where(slug: params[:conference_slug]))
      .not_withdrawn
      .first
  end

  helper_method def current_conference
    return @current_conference if defined? @current_conference
    return nil unless params[:conference_slug]
    @current_conference = current_sponsorship&.conference || Conference.find_by(slug: params[:conference_slug])
  end

  helper_method def current_available_sponsorships
    return @current_available_sponsorships if defined? @current_available_sponsorships
    return nil unless session[:sponsorship_ids]
    @current_available_sponsorships = Sponsorship.includes(:conference).where(id: session[:sponsorship_ids]).not_withdrawn.order(id: :desc)
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

  def populate_sentry_scope
    Sentry.configure_scope do |scope|
      if current_staff
        scope.set_context(
          'sponsor-app.staff',
          {
            id: current_staff.id,
            login: current_staff.login,
          }
        )
      end

      if current_sponsorship
        scope.set_context(
          'sponsor-app.sponsor',
          {
            id: current_sponsorship.id,
            name: current_sponsorship.name,
          }
        )
      end

      if current_conference
        scope.set_context(
          'sponsor-app.conference',
          {
            id: current_conference.id,
            slug: current_conference.slug,
          }
        )
      end

      case
      when current_staff
        Sentry.set_user(id: "staff_#{current_staff.id}", username: current_staff.login)
      when current_sponsorship
        email = session[:email] ||= current_sponsorship.contact&.email
        Sentry.set_user(id: "#{current_sponsorship.id}", email: )
      end
    end
  end
end
