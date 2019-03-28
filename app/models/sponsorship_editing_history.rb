class SponsorshipEditingHistory < ApplicationRecord
  belongs_to :sponsorship
  include EditingHistory

  def target
    sponsorship
  end
end
