# typed: strict
# frozen_string_literal: true

# @requires_ancestor: ActiveRecord::Base
module EditingHistoryTarget
  extend ActiveSupport::Concern

  #: type history = SponsorshipEditingHistory | SponsorEventEditingHistory | ExhibitionEditingHistory

  included do
    has_many :editing_histories, -> { order(id: :desc) }, class_name: "#{name}EditingHistory", dependent: :destroy, inverse_of: false
    around_save :create_history
  end

  #: Staff?
  attr_accessor :staff

  #: () -> history?
  def last_editing_history
    @last_editing_history ||= editing_histories.order(id: :asc).last #: history?
  end

  #: () { () -> void } -> void
  def create_history(&_block)
    yield
    @last_editing_history = editing_histories.create!(
      staff: staff,
      raw: to_h_for_history,
    )
  end
end
