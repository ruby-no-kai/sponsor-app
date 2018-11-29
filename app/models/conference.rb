class Conference < ApplicationRecord
  has_many :form_descriptions, dependent: :destroy
  has_many :plans, -> { order(rank: :asc) }, dependent: :destroy
  has_many :sponsorships, dependent: :destroy

  scope :application_open, -> { t = Time.now; where('application_opens_at <= ? AND (application_closes_at > ? OR application_closes_at IS NULL) AND application_opens_at IS NOT NULL', t, t) }
  scope :amendment_open, -> { t = Time.now; where('application_opens_at <= ? AND (amendment_closes_at > ? OR amendment_closes_at IS NULL) AND application_opens_at IS NOT NULL', t, t) }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :contact_email_address, presence: true

  def application_open?
    t = Time.now
    application_opens_at && application_opens_at <= t && (!application_closes_at || t < application_closes_at)
  end

  def amendment_open?
    t = Time.now
    application_opens_at && application_opens_at <= t && (!amendment_closes_at || t < amendment_closes_at)
  end

  def form_description_for_locale
    form_descriptions.find_by(locale: I18n.locale) || form_descriptions.find_by!(locale: 'en')
  end
end
