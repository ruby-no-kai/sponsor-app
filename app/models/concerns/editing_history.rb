# typed: strict
# frozen_string_literal: true

# @requires_ancestor: ActiveRecord::Base
module EditingHistory
  extend ActiveSupport::Concern

  included do
    belongs_to :staff, optional: true

    validates :raw, presence: true

    before_validation :calculate_diff
  end

  #: () -> Array[EditingHistoryChange]
  def diff_changes
    Must.because(diff) { "diff is calculated before validation" }.map { EditingHistoryChange.new(it) }
  end

  #: () -> Array[String]
  def diff_summary
    diff_changes.map { "#{it.operation}#{it.path}" }
  end

  #: () -> void
  private def calculate_diff
    self.diff = Hashdiff.diff(last_raw, raw) unless diff
  end

  #: () -> Hash[String, untyped]
  private def last_raw
    @last_raw ||= if persisted?
      Must.expect(target).editing_histories.order(id: :desc).where('id < ?', id).first&.raw || {}
    else
      target&.editing_histories&.order(id: :desc)&.first&.raw || {}
    end #: Hash[String, untyped]?
  end
end
