# frozen_string_literal: true

class ExpenseFile < ApplicationRecord
  include AssetFileUploadable

  MAX_FILE_SIZE = 20.megabytes

  belongs_to :sponsorship
  has_many :expense_line_item_files, dependent: :destroy

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
