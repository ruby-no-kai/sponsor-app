# typed: true
# frozen_string_literal: true

# @requires_ancestor: ActiveRecord::Base
module EditingHistory
  extend ActiveSupport::Concern

  included do
    belongs_to :staff, optional: true

    validates :raw, presence: true

    before_validation :calculate_diff
  end

  def diff_summary
    Must.because(diff) { "diff is calculated before validation" }.map { |d| "#{d[0]}#{d[1]}" }
  end

  private def calculate_diff
    self.diff = Hashdiff.diff(last_raw, raw) unless diff
  end

  private def last_raw
    @last_raw ||= if persisted?
      Must.expect(target).editing_histories.order(id: :desc).where('id < ?', id).first&.raw || {}
    else
      target&.editing_histories&.order(id: :desc)&.first&.raw || {}
    end
  end
end
