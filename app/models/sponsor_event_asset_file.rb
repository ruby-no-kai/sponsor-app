class SponsorEventAssetFile < ApplicationRecord
  include AssetFileUploadable

  MAX_FILE_SIZE = 20.megabytes

  belongs_to :sponsor_event, optional: true

  validates :extension, inclusion: { in: %w[png jpg jpeg webp] }, allow_nil: true
  validate :validate_ownership_not_changed

  def self.prepare(conference:, sponsorship:)
    record = new
    record.prefix = "c-#{conference.id}/events/s-#{sponsorship.id}/"
    record
  end

  def filename
    "E#{id}_#{sponsor_event&.slug}.#{extension}"
  end

  private

  def validate_ownership_not_changed
    if sponsor_event_id_changed? && !sponsor_event_id_was.nil?
      errors.add :sponsor_event_id, "cannot be changed"
    end
  end
end
