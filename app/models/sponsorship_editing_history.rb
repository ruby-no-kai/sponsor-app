# typed: strict
# frozen_string_literal: true

class SponsorshipEditingHistory < ApplicationRecord
  belongs_to :sponsorship
  include EditingHistory

  #: () -> Sponsorship?
  def target
    sponsorship
  end
end
