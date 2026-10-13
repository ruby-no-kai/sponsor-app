# typed: strict
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include LocaleSelectable

  before_action :select_locale
  before_action :populate_sentry_scope

  #: () -> Staff?
  helper_method def current_staff_maybe
    return @current_staff if defined? @current_staff

    staff_id = session[:staff_id]
    @current_staff = (Staff.find_by(id: staff_id) if staff_id) #: Staff?
  end

  #: () -> Staff
  helper_method def current_staff = Must.because(current_staff_maybe) { "require_staff gates this action" }

  #: () -> Sponsorship?
  helper_method def current_sponsorship_maybe
    return @current_sponsorship if defined? @current_sponsorship
    return unless params[:conference_slug]
    return unless session[:sponsorship_ids]

    @current_sponsorship = Sponsorship.where(id: session[:sponsorship_ids])
      .joins(:conference)
      .merge(Conference.where(slug: params[:conference_slug]))
      .not_withdrawn
      .first #: Sponsorship?
  end

  #: () -> Sponsorship
  helper_method def current_sponsorship = Must.because(current_sponsorship_maybe) { "require_sponsorship_session gates this action" }

  #: () -> Conference?
  helper_method def current_conference_maybe
    return @current_conference if defined? @current_conference
    return unless params[:conference_slug]

    @current_conference = current_sponsorship_maybe&.conference || Conference.find_by(slug: params[:conference_slug]) #: Conference?
  end

  #: () -> Conference
  helper_method def current_conference = Must.because(current_conference_maybe) { "require_sponsorship_session gates this action" }

  #: () -> Sponsorship::PrivateRelation?
  helper_method def current_available_sponsorships
    return @current_available_sponsorships if defined? @current_available_sponsorships
    return unless session[:sponsorship_ids]

    @current_available_sponsorships = Sponsorship.includes(:conference).where(id: session[:sponsorship_ids]).not_withdrawn.order(id: :desc) #: Sponsorship::PrivateRelation?
  end

  #: () -> void
  private def require_staff
    unless current_staff_maybe
      redirect_to new_session_path(back_to: url_for(params.to_unsafe_h.merge(only_path: true)))
    end
  end

  #: () -> void
  private def require_sponsorship_session
    unless current_sponsorship_maybe
      redirect_to new_user_session_path(back_to: url_for(params.to_unsafe_h.merge(only_path: true)))
    end
  end

  #: () -> void
  private def populate_sentry_scope
    Sentry.configure_scope do |scope|
      staff = current_staff_maybe
      sponsorship = current_sponsorship_maybe
      conference = current_conference_maybe

      if staff
        scope.set_context(
          'sponsor-app.staff',
          {
            id: staff.id,
            login: staff.login,
          },
        )
      end

      if sponsorship
        scope.set_context(
          'sponsor-app.sponsor',
          {
            id: sponsorship.id,
            name: sponsorship.name,
          },
        )
      end

      if conference
        scope.set_context(
          'sponsor-app.conference',
          {
            id: conference.id,
            slug: conference.slug,
          },
        )
      end

      case
      when staff
        Sentry.set_user(id: "staff_#{staff.id}", username: staff.login)
      when sponsorship
        email = session[:email] ||= sponsorship.contact&.email
        Sentry.set_user(id: sponsorship.id.to_s, email:)
      end
    end
  end
end
