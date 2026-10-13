# typed: strict
# frozen_string_literal: true

# The locale texts SponsorService.GetTranslations serves to the sponsor area, flattened to dotted
# keys such as "layouts.application.login". Only the scopes listed here leave the server, which
# keeps staff and mailer texts out.
module SponsorTranslations
  SCOPES = [
    # Shell
    'layouts.application',
    'root.index',
    'conferences.index',
    'sponsorships.show',
    'activerecord.attributes.expense_report/status',
    'sponsor_ui.shell',
    'sponsor_ui.dashboard',

    # Applications
    'sponsorships.new',
    'sponsorships.edit',
    'sponsorships.form',
    'sponsorships.closed',
    'sponsorships.create',
    'activerecord.attributes.sponsorship',
    'activerecord.attributes.sponsorship/note',
    'activerecord.attributes.sponsorship/customization_request',
    'activerecord.attributes.sponsorship/billing_request',
    'activerecord.attributes.contact',
    'helpers.label.sponsorship',
    'sponsor_ui.applications',
    'sponsor_ui.files',

    # Exhibitions and events

    # Broadcasts and passes
    'broadcasts',
    'pass_redemptions',
    'sponsor_ui.broadcasts',

    # Expense reports
  ].freeze #: Array[String]

  # Every scope's texts in the locale, each missing one given in English as I18n's fallback would.
  #: (String) -> Hash[String, String]
  def self.for(locale)
    translations = {} #: Hash[String, String]
    SCOPES.each do |scope|
      english = Must.be_a(I18n.t(scope, locale: :en, raise: true), Hash)
      localized = Must.be_a(I18n.t(scope, locale:, raise: true), Hash)
      flatten(scope, english.deep_merge(localized), translations)
    end
    translations
  end

  #: (String, untyped, Hash[String, String]) -> void
  private_class_method def self.flatten(key, value, translations)
    case value
    when Hash
      value.each { |name, child| flatten("#{key}.#{name}", child, translations) }
    when String
      translations[key] = value
    else
      raise ArgumentError, "#{key} holds a #{value.class}, and translations are strings only"
    end
  end
end
