class BroadcastDelivery < ApplicationRecord
  belongs_to :broadcast
  belongs_to :sponsorship, optional: true

  validates :recipient, presence: true
  validates :status, presence: true

  enum status: %i(created preparing ready pending sending sent failed rejected accepted delivered opened)
end
