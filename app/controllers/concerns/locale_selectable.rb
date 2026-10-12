# typed: strict
# frozen_string_literal: true

# Picks the request's locale from `?hl=`, the locale cookie, the session or the viewer's country,
# and remembers the choice in the locale cookie.
#
# @requires_ancestor: ActionController::Metal
# @requires_ancestor: ActionController::Cookies
# @requires_ancestor: ActionController::StrongParameters
module LocaleSelectable
  #: () -> void
  private def set_locale
    locale_cookie_name = Rails.application.config.x.locale_cookie_name #: String

    case
    when params[:hl]
      if I18n.available_locales.include?(params[:hl].to_sym)
        write_locale_cookie(params[:hl].to_sym)
      else
        cookies.delete(locale_cookie_name, path: '/')
      end
    when cookies[locale_cookie_name]
      # use cookie value
    when session[:hl]
      write_locale_cookie(session[:hl].to_sym)
    when request.headers['HTTP_CLOUDFRONT_VIEWER_COUNTRY']&.downcase == 'jp'
      write_locale_cookie(:ja)
    end

    hl = cookies[locale_cookie_name]&.to_sym.presence
    hl = session[:hl] if hl.nil?
    I18n.locale = hl if hl && I18n.available_locales.include?(hl)
  end

  #: (Symbol) -> void
  private def write_locale_cookie(locale)
    name = Rails.application.config.x.locale_cookie_name #: String
    opts = {value: locale.to_s, expires: 1.year, path: '/', same_site: :lax, secure: true, httponly: false}
    cookies[name] = opts
  end
end
