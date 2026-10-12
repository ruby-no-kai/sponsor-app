# typed: true
# frozen_string_literal: true

# @requires_ancestor: ActiveRecord::Base
module EditingHistoryTarget
  extend ActiveSupport::Concern

  included do
    has_many :editing_histories, -> { order(id: :desc) }, class_name: "#{name}EditingHistory", dependent: :destroy, inverse_of: false
    around_save :create_history
  end

  attr_accessor :staff

  def last_editing_history
    @last_editing_history ||= editing_histories.order(id: :asc).last
  end

  def create_history
    yield
    @last_editing_history = editing_histories.create!(
      staff: staff,
      raw: to_h_for_history,
    )
  end
end
