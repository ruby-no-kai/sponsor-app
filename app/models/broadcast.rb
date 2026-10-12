# typed: strict
# frozen_string_literal: true

class Broadcast < ApplicationRecord
  include MarkdownBody

  belongs_to :conference
  belongs_to :staff

  has_many :deliveries, class_name: 'BroadcastDelivery', dependent: :destroy

  enum :status, {created: 0, preparing: 1, modifying: 2, ready: 3, pending: 4, sending: 5, sent: 6, failed: 7}

  validates :campaign, presence: true
  validates :status, presence: true
  validates :title, presence: true
  validates :body, presence: true
  validate :forbid_changes_to_delivered_content, if: ->(record) { record.persisted? && record.status_was == 'sent' }

  #: (?now: ActiveSupport::TimeWithZone) -> void
  def perform_later!(now: Time.current)
    update!(status: :pending, dispatched_at: now)
    deliveries.each do |delivery|
      delivery.update!(status: :pending)
      DispatchBroadcastDeliveryJob.perform_later(delivery)
    end
  end

  #: () -> self
  def update_status
    return self if created? || preparing? || modifying? || ready?

    statuses = deliveries.distinct.order(status: :asc).pluck(:status)
    self.status = case
    when statuses == %w(pending), statuses == %w(created pending)
      :pending
    when (statuses - %w(sent failed rejected accepted delivered opened clicked)).empty?
      :sent
    else
      :sending
    end
    self
  end

  #: () -> void
  private def forbid_changes_to_delivered_content
    errors.add(:title, 'cannot be changed after dispatch') if title_changed?
    errors.add(:body, 'cannot be changed after dispatch') if body_changed?
  end
end
