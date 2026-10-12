# typed: strict
# frozen_string_literal: true

class SponsorEventEditingHistory < ApplicationRecord
  include EditingHistory

  belongs_to :sponsor_event

  #: () -> SponsorEvent?
  def target
    sponsor_event
  end
end
