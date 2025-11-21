require 'securerandom'

class Sponsorship < ApplicationRecord
  include EditingHistoryTarget

  belongs_to :conference
  belongs_to :organization
  belongs_to :plan, optional: true

  has_many :contacts, dependent: :destroy
  has_one :contact, -> { where(kind: :primary) }, class_name: 'Contact'
  has_one :alternate_billing_contact, -> { where(kind: :billing) }, class_name: 'Contact'

  has_many :requests, dependent: :destroy, class_name: 'SponsorshipRequest'
  has_one :billing_request, -> { where(kind: :billing) }, class_name: 'SponsorshipRequest'
  has_one :customization_request, -> { where(kind: :customization) }, class_name: 'SponsorshipRequest'
  has_one :note, -> { where(kind: :note) }, class_name: 'SponsorshipRequest'

  has_one :asset_file, class_name: 'SponsorshipAssetFile', dependent: :destroy

  has_one :tito_source

  def asset_file_id; self.asset_file&.id; end
  def asset_file_id=(other)
    self.asset_file = SponsorshipAssetFile.find_by(id: other.to_i)
  end

  has_many :staff_notes, class_name: 'SponsorshipStaffNote', dependent: :destroy

  has_one :exhibition

  has_many :broadcast_deliveries, dependent: :nullify

  has_many :tito_discount_codes, dependent: :destroy

  def tito_attendee_discount_code
    @tito_attendee_discount_code ||= tito_discount_codes.where(kind: 'attendee').first
  end

  def tito_booth_staff_discount_code
    @tito_booth_staff_discount_code ||= tito_discount_codes.where(kind: 'booth_staff').first
  end

  def tito_booth_paid_discount_code
    @tito_booth_paid_discount_code ||= tito_discount_codes.where(kind: 'booth_paid').first
  end

  scope :active, -> { accepted.not_withdrawn }
  scope :pending, -> { not_accepted.not_withdrawn }

  scope :exhibitor, -> { where(booth_assigned: true) }
  scope :plan_determined, -> { where.not(plan_id: nil) }

  scope :withdrawn, -> { where.not(withdrawn_at: nil) }
  scope :not_withdrawn, -> { where(withdrawn_at: nil) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :not_accepted, -> { where(accepted_at: nil) }

  scope :have_presence, -> { where(suspended: false).merge(Sponsorship.active).merge(Sponsorship.plan_determined) }

  scope :includes_contacts, -> { includes(:contact, :alternate_billing_contact) }
  scope :includes_requests, -> { includes(:billing_request, :customization_request, :note) }

  validates :organization, presence: true, uniqueness: {scope: :conference_id}

  validates :contact, presence: true

  validates :name, presence: true
  validates :url, presence: true
  validates :profile, presence: true

  validates :asset_file, presence: true

  validates_numericality_of :number_of_additional_attendees, allow_nil: true, greater_than_or_equal_to: 0, only_integer: true

  validate :validate_correct_plan
  validate :validate_plan_change, on: :update_by_user
  validate :validate_plan_availability, on: :update_by_user
  validate :validate_booth_eligibility, on: :update_by_user
  validate :validate_word_count, on: :update_by_user
  validate :validate_no_plan_allowance, on: :update_by_user
  validate :validate_fallback_option, on: :update_by_user
  validate :policy_agreement


  accepts_nested_attributes_for :contact, allow_destroy: true,reject_if: -> (attrs) { attrs['kind'].present? }
  accepts_nested_attributes_for :alternate_billing_contact, allow_destroy: true, reject_if: -> (attrs) { attrs['kind'].present? }

  accepts_nested_attributes_for :billing_request, reject_if: -> (attrs) { attrs['kind'].present? }
  accepts_nested_attributes_for :customization_request, reject_if: -> (attrs) { attrs['kind'].present? }
  accepts_nested_attributes_for :note, reject_if: -> (attrs) { attrs['kind'].present? }

  before_validation :generate_ticket_key

  def build_nested_attributes_associations
    self.build_contact unless self.contact
    self.build_alternate_billing_contact unless self.alternate_billing_contact
    self.build_billing_request unless self.billing_request
    self.build_customization_request unless self.customization_request
    self.build_note unless self.note
  end

  def active?
    accepted? && !withdrawn?
  end

  def accept
    self.accepted_at = Time.zone.now
  end

  def accepted?
    !!accepted_at
  end

  def accepted
    accepted?
  end

  def accepted=(x)
    case
    when !x || x == '0'
      self.accepted_at = nil
    when x && !accepted?
      self.accepted_at = Time.zone.now
    else
      accepted?
    end
  end

  def withdrawn?
    !!withdrawn_at
  end

  def customized?
    customization && customization_name.present?
  end

  def customization_planned?
    !customization && customization_name.present?
  end

  def plan_name
    customized? ? (customization_name || plan&.name) : plan&.name
  end

  def slug
    self.organization&.slug
  end

  def word_count
    profile&.scan(/[\w\-'’]+/)&.size || 0
  end

  def policy_agreement
    return @policy_agreement if defined? @policy_agreement
    @policy_agreement = self.persisted?
  end

  def policy_agreement=(other)
    @policy_agreement = !!other
  end

  def billing_contact
    alternate_billing_contact || contact
  end

  def assume_organization
    self.organization = Organization.create_with(name: self.name).find_or_initialize_by(domain: self.contact&.email&.split(?@, 2)&.last&.downcase)
  end

  def to_h_for_history
    {
      "conference_id" => conference&.id,
      "contact" => contact&.as_json&.slice("id", "name", "email", "email_cc", "organization", "unit", "address"),
      "alternate_billing_contact" => alternate_billing_contact&.as_json&.slice("id", "name", "email", "email_cc", "organization", "unit", "address"),
      "billing_request" => billing_request&.body,
      "plan_id" => plan&.id,
      "plan_name" => plan&.name,
      "plan_display_name" => plan_name,
      "customization_name" => customization_name,
      "customized?" => customized?,
      "suspended?" => suspended?,
      "customization_planned?" => customization_planned?,
      "customization_request" => customization_request&.body,
      "booth_requested" => booth_requested,
      "booth_assigned" => booth_assigned,
      "name" => name,
      "url" => url,
      "profile" => profile,
      "organization_id" => organization&.id,
      "organization_name" => organization&.name,
      "locale" => locale,
      "asset_file_id" => asset_file&.id,
      "asset_file.extension" => asset_file&.extension,
      "asset_file.version_id" => asset_file&.version_id,
      "asset_file.checksum_sha256" => asset_file&.checksum_sha256,
      "asset_file.last_modified_at" => asset_file&.last_modified_at,
      "note" => note&.body,
      "fallback_option" => fallback_option,
      "number_of_additional_attendees" => number_of_additional_attendees,
      "accepted_at" => accepted_at,
    }.tap do |h|
      h["withdrawn_at"] = withdrawn_at if withdrawn_at
    end
  end

  def attributes_for_copy
    {
      name: self.name,
      url: self.url,
      profile: self.profile,
      asset_file_id: self.asset_file_id,
      contact_attributes: self.contact.attributes.except('id', 'kind'),
      alternate_billing_contact_attributes: self.alternate_billing_contact&.attributes&.except('id', 'kind')&.merge(_keep: '1'),
      billing_request_attributes: self.billing_request&.attributes&.except('id', 'kind'),
    }.compact
  end

  def total_number_of_attendees
    if active?
      (plan&.number_of_guests || 0) + (number_of_additional_attendees || 0)
    else
      0
    end
  end
  
  def total_number_of_booth_staff
    #(active? && booth_assigned?) ? [3, booth_size ? booth_size*2 : 0].max : 0 # FIXME:
    (active? && booth_assigned?) ? 2 : 0 # FIXME:
  end

  def booth_size
    plan&.booth_size
  end

  def assigned_booth_size
    booth_assigned? ? (plan&.booth_size || 0) : 0
  end

  def exhibitor?
    booth_assigned?
  end

  def withdraw
    self.withdrawn_at = Time.zone.now
    self.booth_assigned = false
    self.plan = nil
    return self
  end

  private

  def validate_correct_plan
    if plan && plan.conference_id != self.conference_id
      errors.add :plan, "can't have a plan for an another conference"
    end
  end

  def validate_plan_availability
    if plan && plan_id_changed? && !plan.available?
      errors.add :plan, :unavailable
    end
  end

  def validate_plan_change
    if plan_id_changed? && plan_id_was && accepted?
      errors.add :plan, :unchangeable_after_finalization
    end
  end

  def validate_policy_agreement
    if !policy_agreement
      errors.add :policy_agreement, "must agree with the policy"
    end
  end

  def validate_booth_eligibility
    if booth_requested && !(plan&.booth_eligible?)
      errors.add :booth_requested, :not_eligible
    end
  end

  def validate_word_count
    limit = plan&.words_limit_hard
    if limit && word_count > limit
      errors.add :profile, :too_long, maximum: (plan.words_limit || 0)
    end
  end

  def validate_no_plan_allowance
    if !plan_id && conference && !conference.no_plan_allowed
      errors.add :plan, :no_plan_not_allowed
    end
  end

  def validate_fallback_option
    form_desc = conference&.form_description_for_locale
    return unless form_desc

    fallback_options = form_desc.fallback_options
    if fallback_options.present? && fallback_options.any?
      if fallback_option.present? && !fallback_options.any? { |opt| opt.value == fallback_option }
        errors.add :fallback_option, :invalid
      end
    end
  end

  def generate_ticket_key
    if self.ticket_key.blank?
      begin
        self.ticket_key = SecureRandom.urlsafe_base64(64)
      end while self.class.where(conference: conference, ticket_key: self.ticket_key).exists?
    end
  end
end
