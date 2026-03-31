# frozen_string_literal: true

class SponsorEventAssetFile < ApplicationRecord
  include AssetFileUploadable

  MAX_FILE_SIZE = 20.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  belongs_to :sponsorship
  belongs_to :sponsor_event, optional: true

  validates :extension, inclusion: {in: %w[png jpg jpeg webp]}, allow_nil: true
  validate :content_type_allowed
  validate :validate_ownership_not_changed

  def self.prepare(conference:, sponsorship:)
    record = new
    record.sponsorship = sponsorship
    record.prefix = "c-#{conference.id}/events/s-#{sponsorship.id}/"
    record
  end

  def filename
    "E#{id}_#{sponsor_event&.slug}.#{extension}"
  end

  private def content_type_allowed
    return if content_type.blank?
    return if content_type.in?(ALLOWED_CONTENT_TYPES)

    errors.add(:content_type, "must be an image (JPEG, PNG, GIF, WebP)")
  end

  private def validate_ownership_not_changed
    if sponsor_event_id_changed? && !sponsor_event_id_was.nil?
      errors.add :sponsor_event_id, "cannot be changed"
    end
  end
end
