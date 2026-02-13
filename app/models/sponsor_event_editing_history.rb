class SponsorEventEditingHistory < ApplicationRecord
  include EditingHistory

  belongs_to :sponsor_event

  def target
    sponsor_event
  end
end
