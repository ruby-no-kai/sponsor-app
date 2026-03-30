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

  def perform_later!(now: Time.current)
    update!(status: :pending, dispatched_at: now)
    deliveries.each do |delivery|
      delivery.update!(status: :pending)
      DispatchBroadcastDeliveryJob.perform_later(delivery)
    end
  end

  def update_status
    return self if preparing? || created? || preparing? || modifying?

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
end
