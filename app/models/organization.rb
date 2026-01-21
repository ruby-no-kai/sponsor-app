class Organization < ApplicationRecord
  attribute :affiliation_code, :string, default: -> { SecureRandom.urlsafe_base64(24) }

  has_many :sponsorships
  validates :name, presence: true
  validates :domain, presence: true
  validates :affiliation_code, presence: true, uniqueness: true

  def slug
    domain
  end

  def to_param
    domain
  end

  def self.find_by_affiliation_code(code)
    return nil if code.blank?
    find_by(affiliation_code: code)
  end

  def affiliation_url(conference)
    Rails.application.routes.url_helpers.new_user_conference_sponsorship_url(
      conference_slug: conference.slug,
      affiliation: affiliation_code,
      host: Rails.application.config.action_mailer.default_url_options&.fetch(:host) || 'localhost:3000'
    )
  end
end
