# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService locale', type: :request do
  let(:get_translations) { connect_method('SponsorService', 'GetTranslations') }
  let(:set_locale) { connect_method('SponsorService', 'SetLocale') }
  let(:translations_request) { Rk::SponsorApp::SponsorServiceGetTranslationsRequest.new }

  def set_locale_request(locale) = Rk::SponsorApp::SponsorServiceSetLocaleRequest.new(locale:)

  describe 'GetTranslations' do
    it 'returns the English texts by dotted key, plurals split by form' do
      response = connect_call(get_translations, translations_request)

      expect(response.locale).to eq('en')
      expect(response.org_name).to eq(Rails.application.config.x.org_name)
      expect(response.translations.to_h).to include(
        'layouts.application.login' => 'Log in',
        'root.index.sponsor_conference' => 'Sponsor %{conference}',
        'sponsorships.show.tickets.quantity.one' => '%{count} pass',
        'sponsorships.show.tickets.quantity.other' => '%{count} passes',
        'activerecord.attributes.expense_report/status.draft' => 'Draft',
        'sponsor_ui.shell.site_name' => '%{org_name} Sponsorships Portal',
        'sponsorships.form.plan_explanation.guests.other' => '%{count} guests',
        'activerecord.attributes.contact.email' => 'Email Address',
        'helpers.label.sponsorship.booth_requested' => 'Request a Booth',
      )
    end

    it 'answers a GET and a binary call alike' do
      expected = connect_call(get_translations, translations_request)

      expect(connect_call(get_translations, translations_request, via: :get)).to eq(expected)
      expect(connect_call(get_translations, translations_request, codec: :proto)).to eq(expected)
    end

    it 'serves only the allowlisted scopes, never staff texts' do
      keys = connect_call(get_translations, translations_request).translations.keys
      prefixes = SponsorTranslations::SCOPES.map { "#{it}." }

      expect(keys).to all(satisfy { |key| key.start_with?(*prefixes) })
      expect(keys.grep(/\Aadmin\./)).to be_empty
      expect(I18n.t('admin', locale: :en)).to be_a(Hash)
    end

    it 'serves every group of the SPA texts' do
      groups = I18n.t('sponsor_ui', locale: :en).keys.map { "sponsor_ui.#{it}" }

      expect(SponsorTranslations::SCOPES).to include(*groups)
    end

    context 'with Japanese chosen' do
      before do
        https! # The locale cookie is Secure.
        cookies[Rails.application.config.x.locale_cookie_name] = 'ja'
      end

      it 'returns the Japanese texts' do
        response = connect_call(get_translations, translations_request)

        expect(response.locale).to eq('ja')
        expect(response.translations['layouts.application.login']).to eq('ログイン')
        expect(response.translations['sponsor_ui.shell.site_name']).to eq('%{org_name} スポンサーポータル')
      end

      it 'fills a text Japanese lacks with the English one' do
        expect(I18n.exists?('sponsorships.show.total_number_of_guests', :ja, fallback: false)).to be(false)

        expect(connect_call(get_translations, translations_request).translations['sponsorships.show.total_number_of_guests'])
          .to eq('Total')
      end

      it 'has a Japanese text for every English one of the SPA' do
        en = SponsorTranslations.for('en').keys.grep(/\Asponsor_ui\./)
        ja = en.select { I18n.exists?(it, :ja, fallback: false) }

        expect(ja).to eq(en)
      end
    end
  end

  describe 'SetLocale' do
    before { https! }

    it 'remembers the locale in the cookie for the requests that follow' do
      expect(connect_call(set_locale, set_locale_request('ja'))).to eq(Rk::SponsorApp::SponsorServiceSetLocaleResponse.new)
      expect(cookies[Rails.application.config.x.locale_cookie_name]).to eq('ja')

      expect(connect_call(get_translations, translations_request).locale).to eq('ja')
      expect(connect_call(connect_method('SponsorService', 'GetViewer'), Rk::SponsorApp::SponsorServiceGetViewerRequest.new).viewer.locale)
        .to eq('ja')

      connect_call(set_locale, set_locale_request('en'))
      expect(connect_call(get_translations, translations_request).locale).to eq('en')
    end

    it 'answers invalid_argument for a locale it does not offer, keeping the cookie' do
      connect_call(set_locale, set_locale_request('ja'))

      error = connect_call(set_locale, set_locale_request('fr'))

      expect(error).to have_attributes(code: 'invalid_argument')
      expect(violations_of(error)).to eq([['locale', 'STRING_IN']])
      expect(cookies[Rails.application.config.x.locale_cookie_name]).to eq('ja')
    end

    it 'refuses a GET, as it has side effects' do
      get "#{set_locale.path}?connect=v1&encoding=json&message=#{CGI.escape('{"locale":"ja"}')}"

      expect(response).to have_http_status(:method_not_allowed)
    end
  end
end
