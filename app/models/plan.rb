class Plan < ApplicationRecord
  belongs_to :conference
  has_many :sponsorships

  validates :name, presence: true
  validates :price_text, presence: true
  validates :words_limit, presence: true

  def booth_eligible?
    (booth_size || 0) > 0
  end

  def available?(t = Time.zone.now)
    !sold_out? && !closed?(t)
  end

  def sold_out?
    !capacity || sponsorships.active.count > capacity
  end

  def closed?(t = Time.zone.now)
    closes_at ? closes_at <= t : false
  end

  def words_limit_hard
    # TODO:
    (words_limit || 0) * 1.1
  end
end
