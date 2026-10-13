# typed: strict
# frozen_string_literal: true

class Organization < ApplicationRecord
  attribute :affiliation_code, :string, default: -> { SecureRandom.urlsafe_base64(24) }

  has_many :sponsorships, dependent: nil
  validates :name, presence: true
  validates :domain, presence: true, uniqueness: true
  validates :affiliation_code, presence: true, uniqueness: true

  # Loads each organization's sponsorship_count in the same query, sparing a COUNT per organization.
  scope :with_sponsorship_count, -> {
    count = Sponsorship.where(Sponsorship.arel_table[:organization_id].eq(arel_table[:id])).select(Arel.star.count)
    select(arel_table[Arel.star], count.arel.as('sponsorship_count'))
  }

  # Sponsorships of the organization across conferences, withdrawn ones included.
  #: () -> Integer
  def sponsorship_count
    return sponsorships.count unless has_attribute?(:sponsorship_count)

    self[:sponsorship_count]
  end

  #: () -> String
  def slug
    domain
  end

  #: () -> String
  def to_param
    domain
  end

  #: (String? code) -> Organization?
  def self.find_by_affiliation_code(code)
    return if code.blank?

    find_by(affiliation_code: code)
  end

  #: (Conference conference) -> String
  def affiliation_url(conference)
    Rails.application.routes.url_helpers.new_user_conference_sponsorship_url(
      conference_slug: conference.slug,
      affiliation: affiliation_code,
      host: Rails.application.config.action_mailer.default_url_options&.fetch(:host) || 'localhost:3000',
    )
  end
end
