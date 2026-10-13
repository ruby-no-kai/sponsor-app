# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    class LocaleController < Api::Sponsor::ApplicationController
      authorize :public
      #: () -> Rk::SponsorApp::SponsorServiceGetTranslationsResponse
      def get_translations
        locale = I18n.locale.to_s
        org_name = Rails.application.config.x.org_name #: String

        Rk::SponsorApp::SponsorServiceGetTranslationsResponse.new(
          locale:,
          translations: SponsorTranslations.for(locale),
          org_name:,
        )
      end

      # The SPA's page loads never reach Rails, and an RPC carries no `hl`, so this stands in for
      # `?hl=` there.
      authorize :public
      #: () -> Rk::SponsorApp::SponsorServiceSetLocaleResponse
      def set_locale
        locale = connect_request.locale #: String
        write_locale_cookie(locale.to_sym)
        I18n.locale = locale

        Rk::SponsorApp::SponsorServiceSetLocaleResponse.new
      end
    end
  end
end
