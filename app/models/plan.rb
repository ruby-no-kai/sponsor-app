# typed: strict
# frozen_string_literal: true

class Plan < ApplicationRecord
  belongs_to :conference
  has_many :sponsorships, dependent: nil

  validates :name, presence: true
  validates :price_text, presence: true
  validates :words_limit, presence: true

  # Loads each plan's active_sponsorship_count in the same query, sparing a COUNT per plan.
  scope :with_active_sponsorship_count, -> {
    active_count = Sponsorship.active.where(Sponsorship.arel_table[:plan_id].eq(arel_table[:id])).select(Arel.star.count)
    select(arel_table[Arel.star], active_count.arel.as('active_sponsorship_count'))
  }

  # Accepted sponsorships on this plan that have not withdrawn, which is what capacity limits.
  #: () -> Integer
  def active_sponsorship_count
    return sponsorships.active.count unless has_attribute?(:active_sponsorship_count)

    self[:active_sponsorship_count]
  end

  #: () -> bool
  def booth_eligible?
    (booth_size || 0) > 0
  end

  #: (?ActiveSupport::TimeWithZone t) -> bool
  def available?(t = Time.zone.now)
    !sold_out? && !closed?(t)
  end

  #: () -> bool
  def sold_out?
    !capacity || sponsorships.active.count >= capacity
  end

  #: (?ActiveSupport::TimeWithZone t) -> bool
  def closed?(t = Time.zone.now)
    at = closes_at
    at ? at <= t : false
  end

  #: () -> Float
  def words_limit_hard
    # TODO: make configurable
    (words_limit || 0) * 1.1
  end
end
