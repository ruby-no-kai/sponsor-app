# frozen_string_literal: true

class ExpenseFile < ApplicationRecord
  include AssetFileUploadable

  MAX_FILE_SIZE = 20.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp application/pdf].freeze

  belongs_to :sponsorship
  has_many :expense_line_item_files, dependent: :destroy

  validate :content_type_allowed

  scope :uploaded, -> { where(status: 'uploaded') }
  scope :pending, -> { where(status: 'pending') }

  def mark_uploaded!
    update!(status: 'uploaded')
  end

  def self.prepare(conference:, sponsorship:)
    record = new
    record.sponsorship = sponsorship
    record.prefix = "c-#{conference.id}/expenses/s-#{sponsorship.id}/"
    record
  end

  def filename
    self[:filename]
  end

  private def content_type_allowed
    return if content_type.blank?
    return if content_type.in?(ALLOWED_CONTENT_TYPES)

    errors.add(:content_type, "must be an image (JPEG, PNG, GIF, WebP) or PDF")
  end
end
