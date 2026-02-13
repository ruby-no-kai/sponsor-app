class SponsorEvent < ApplicationRecord
  include EditingHistoryTarget

  belongs_to :sponsorship
  belongs_to :conference
  has_one :asset_file, class_name: 'SponsorEventAssetFile', dependent: :destroy

  enum :status, { pending: 0, accepted: 1, rejected: 2, withdrawn: 3 }

  validates :slug, presence: true, uniqueness: { scope: :conference_id }
  validates :title, presence: true
  validates :starts_at, presence: true
  validates :url, presence: true, format: { with: %r{\Ahttps?://}, message: "must be a valid HTTP(S) URL" }
  validate :validate_co_host_sponsorship_ids
  validate :validate_policy_acknowledged_on_create, on: :create

  before_validation :set_conference_from_sponsorship
  before_validation :generate_slug, on: :create

  scope :by_starts_at, -> { order(starts_at: :asc) }

  def editable_by_sponsor?
    !withdrawn?
  end

  def to_h_for_history
    {
      "sponsorship_id" => sponsorship_id,
      "conference_id" => conference_id,
      "slug" => slug,
      "title" => title,
      "starts_at" => starts_at&.iso8601,
      "url" => url,
      "price" => price,
      "capacity" => capacity,
      "location_en" => location_en,
      "location_local" => location_local,
      "status" => status,
      "co_host_sponsorship_ids" => co_host_sponsorship_ids,
      "link_name" => link_name,
      "admin_comment" => admin_comment,
      "asset_file_id" => asset_file&.id,
      "asset_file_version_id" => asset_file&.version_id,
      "asset_file_checksum_sha256" => asset_file&.checksum_sha256,
      "policy_acknowledged_at" => policy_acknowledged_at&.iso8601,
    }
  end

  def co_host_sponsorships
    return [] if co_host_sponsorship_ids.blank?
    Sponsorship.where(id: co_host_sponsorship_ids, conference_id:)
  end

  def all_host_sponsorships
    ([sponsorship] + co_host_sponsorships).reject(&:withdrawn?)
  end

  private

  def set_conference_from_sponsorship
    self.conference_id ||= sponsorship&.conference_id
  end

  def generate_slug
    return if slug.present?
    return unless sponsorship&.organization

    sequence = sponsorship.sponsor_events.count + 1
    self.slug = "#{sponsorship.organization.domain}-#{sequence}"
  end

  def validate_co_host_sponsorship_ids
    return if co_host_sponsorship_ids.blank?

    invalid_ids = co_host_sponsorship_ids.reject do |id|
      Sponsorship.exists?(id:, conference_id:)
    end

    if invalid_ids.any?
      errors.add(:co_host_sponsorship_ids, "contains invalid sponsorship IDs: #{invalid_ids.join(', ')}")
    end
  end

  def validate_policy_acknowledged_on_create
    if policy_acknowledged_at.blank?
      errors.add(:policy_acknowledged_at, "must be acknowledged")
    end
  end
end
