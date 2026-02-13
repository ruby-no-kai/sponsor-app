class SponsorshipAssetFile < ApplicationRecord
  include AssetFileUploadable

  belongs_to :sponsorship, optional: true

  scope :available_for_user, ->(id, session_asset_file_ids: [], available_sponsorship_ids: []) do
    where(id:)
      .merge(
        SponsorshipAssetFile.where(sponsorship_id: available_sponsorship_ids)
          .or(SponsorshipAssetFile.where(sponsorship_id: nil, id: session_asset_file_ids || []))
      )
  end

  validate :validate_ownership_not_changed

  def self.prepare(conference:)
    record = new
    record.prefix = "c-#{conference.id}/"
    record
  end

  def copy_to!(conference)
    dst = self.class.prepare(conference:)
    dst.extension = self.extension
    dst.save!
    s3_client.copy_object(
      bucket: self.class.asset_file_bucket,
      copy_source: "#{self.class.asset_file_bucket}/#{object_key}",
      key: dst.object_key,
    )
    dst.update_object_header
    dst
  end

  def filename
    "S#{id}_#{sponsorship&.slug}.#{extension}"
  end

  private

  def validate_ownership_not_changed
    if sponsorship_id_changed? && !sponsorship_id_was.nil?
      errors.add :sponsorship_id, "cannot be changed"
    end
  end
end
