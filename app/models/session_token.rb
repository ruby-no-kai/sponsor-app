# typed: strict
# frozen_string_literal: true

require 'securerandom'

class SessionToken < ApplicationRecord
  belongs_to :sponsorship, optional: true
  belongs_to :staff, optional: true

  validates :handle, presence: true
  validates :expires_at, presence: true

  scope :active, -> { where('expires_at > ?', Time.zone.now) }

  before_validation do
    current_handle = handle #: String?
    unless current_handle
      loop do
        self.handle = SecureRandom.urlsafe_base64(64)
        break unless SessionToken.where(handle: handle).exists?

        sleep 0.1
      end
    end

    current_expires_at = expires_at #: ActiveSupport::TimeWithZone?
    self.expires_at = Time.zone.now + 3.months unless current_expires_at
  end

  #: (?at: ActiveSupport::TimeWithZone) -> bool
  def expired?(at: Time.zone.now)
    expires_at < at
  end

  #: () -> Contact::PrivateRelation
  def contacts
    email ? Contact.where(kind: :primary, email: email) : Contact.none
  end

  #: () -> Array[Sponsorship]
  def sponsorships
    contacts.includes(:sponsorship).map { |contact| Must.because(contact.sponsorship) { "contacts.sponsorship_id is NOT NULL" } }.sort_by(&:id)
  end

  #: () -> Array[Integer]
  def sponsorship_ids
    sponsorships.map(&:id)
  end

  #: () -> String
  def to_param
    handle
  end
end
