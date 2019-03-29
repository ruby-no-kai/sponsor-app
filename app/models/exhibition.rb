class Exhibition < ApplicationRecord
  include EditingHistoryTarget
  belongs_to :sponsorship

  validates :description, presence: true

  def to_h_for_history
    {
      "sponsorship_id" => sponsorship_id,
      "description" => description,
    }
  end
end
