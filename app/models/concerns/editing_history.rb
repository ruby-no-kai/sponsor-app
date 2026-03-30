# frozen_string_literal: true

module EditingHistory
  extend ActiveSupport::Concern

  included do
    belongs_to :staff, optional: true

    validates :raw, presence: true

    before_validation :calculate_diff
  end

  def diff_summary
    diff.map { |d| "#{d[0]}#{d[1]}" }
  end

  private def calculate_diff
    if last_raw && !diff
      self.diff = Hashdiff.diff(last_raw, raw)
    end
  end

  private def last_raw
    @last_raw ||= if persisted?
      target.editing_histories.order(id: :desc).where('id < ?', id).first&.raw || {}
    else
      target&.editing_histories&.order(id: :desc)&.first&.raw || {}
    end
  end
end
