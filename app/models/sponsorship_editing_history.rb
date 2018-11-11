class SponsorshipEditingHistory < ApplicationRecord
  belongs_to :sponsorship
  belongs_to :staff, optional: true

  validates :raw, presence: true

  before_validation :calculate_diff

  private

  def calculate_diff
    if last_raw && !self.diff
      self.diff = HashDiff.diff(last_raw, raw)
      p self.diff
    end
  end

  def last_raw
    @last_raw ||= if self.persisted?
      sponsorship.editing_histories.order(id: :desc).where('id < ?', self.id).first&.raw || {}
    else
      sponsorship&.editing_histories&.order(id: :desc)&.first&.raw || {}
    end
  end
end
