# typed: strict
# frozen_string_literal: true

class Exhibition < ApplicationRecord
  include EditingHistoryTarget
  belongs_to :sponsorship

  validates :description, presence: true

  #: () -> Hash[String, untyped]
  def to_h_for_history
    {
      "sponsorship_id" => sponsorship_id,
      "description" => description,
    }
  end
end
