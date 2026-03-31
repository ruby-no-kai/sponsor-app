# frozen_string_literal: true

class ExpenseFile < ApplicationRecord
  include AssetFileUploadable

  MAX_FILE_SIZE = 20.megabytes

  belongs_to :sponsorship
  has_many :expense_line_item_files, dependent: :destroy

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
end
