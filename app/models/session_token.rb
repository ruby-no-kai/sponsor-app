require 'securerandom'

class SessionToken < ApplicationRecord
  belongs_to :sponsorship, optional: true
  belongs_to :staff, optional: true

  validates :handle, presence: true
  validates :expires_at, presence: true

  scope :active, -> { where('expires_at > ?', Time.zone.now) }

  before_validation do
    unless self.handle
      loop do
        self.handle = SecureRandom.urlsafe_base64(64)
        break unless SessionToken.where(handle: self.handle).exists?
        sleep 0.1
      end
    end

    self.expires_at ||= Time.zone.now + 3.month
  end

  def contacts
    self.email ? Contact.where(kind: :primary, email: self.email) : nil
  end

  def sponsorships
    contacts && contacts.includes(:sponsorship).map(&:sponsorship)
  end

  def to_param
    handle
  end
end
