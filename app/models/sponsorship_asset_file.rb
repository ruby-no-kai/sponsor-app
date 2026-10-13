# typed: strict
# frozen_string_literal: true

class SponsorshipAssetFile < ApplicationRecord
  include AssetFileUploadable

  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg
    image/png
    image/gif
    image/webp
    image/svg+xml
    application/pdf
    application/zip
    application/x-zip-compressed
    application/postscript
    application/illustrator
    application/octet-stream
  ].freeze #: Array[String]

  belongs_to :sponsorship, optional: true

  validate :content_type_allowed

  scope :available_for_user, ->(id, session_asset_file_ids: [], available_sponsorship_ids: []) do
    where(id:)
      .merge(
        SponsorshipAssetFile.where(sponsorship_id: available_sponsorship_ids)
          .or(SponsorshipAssetFile.where(sponsorship_id: nil, id: session_asset_file_ids || [])),
      )
  end

  validate :validate_ownership_not_changed

  #: (conference: Conference) -> SponsorshipAssetFile
  def self.prepare(conference:)
    record = new
    record.prefix = prefix_for(conference)
    record
  end

  #: (Conference) -> String
  def self.prefix_for(conference) = "c-#{conference.id}/"

  # Whether the file was prepared for the conference, as an upload or a copy.
  #: (Conference) -> bool
  def prepared_for?(conference) = prefix == self.class.prefix_for(conference)

  #: (Conference) -> SponsorshipAssetFile
  def copy_to!(conference)
    dst = self.class.prepare(conference:)
    dst.extension = extension
    dst.save!
    s3_client.copy_object(
      bucket: asset_file_bucket,
      copy_source: "#{asset_file_bucket}/#{object_key}",
      key: dst.object_key,
    )
    dst.update_object_header
    dst
  end

  #: () -> String
  def filename
    "S#{id}_#{sponsorship&.slug}.#{extension}"
  end

  #: () -> void
  private def content_type_allowed
    return if content_type.blank?
    return if content_type.in?(ALLOWED_CONTENT_TYPES)

    errors.add(:content_type, "is not an allowed file type")
  end

  #: () -> void
  private def validate_ownership_not_changed
    if sponsorship_id_changed? && !sponsorship_id_was.nil?
      errors.add :sponsorship_id, "cannot be changed"
    end
  end
end
