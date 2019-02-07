class Broadcast < ApplicationRecord
  include MarkdownBody

  belongs_to :conference
  belongs_to :staff

  has_many :deliveries, class_name: 'BroadcastDelivery', dependent: :destroy

  enum status: %i(created preparing modifying ready pending sending sent failed)

  validates :campaign, presence: true
  validates :status, presence: true
  validates :title, presence: true
  validates :body, presence: true

  def perform_later!
    self.update!(status: :pending)
    self.deliveries.each do |delivery|
      delivery.update!(status: :pending)
      DispatchBroadcastDeliveryJob.perform_later(delivery)
    end
  end

  def update_status
    return self if self.preparing? || self.created? || self.preparing? || self.modifying?

    statuses = self.deliveries.distinct.order(status: :asc).pluck(:status)
    case
    when statuses == %w(pending), statuses == %w(created pending)
      self.status = :pending
    when (statuses - %w(sent failed rejected accepted delivered opened clicked)).empty?
      self.status = :sent
    else
      self.status = :sending
    end
    self
  end

end
