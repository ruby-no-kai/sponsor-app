class Sponsorship < ApplicationRecord
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

  def asset_file_id; self.asset_file&.id; end
  def asset_file_id=(other)
    self.asset_file = SponsorshipAssetFile.find_by(id: other.to_i)
  end

  has_many :editing_histories, -> { order(id: :desc) }, class_name: 'SponsorshipEditingHistory', dependent: :destroy
  has_many :staff_notes, class_name: 'SponsorshipStaffNote', dependent: :destroy

  validates :organization, presence: true, uniqueness: {scope: :conference_id}

  validates :contact, presence: true

  validates :name, presence: true
  validates :url, presence: true
  validates :profile, presence: true

  validates :asset_file, presence: true

  validate :validate_correct_plan
  validate :validate_plan_availability
  validate :validate_booth_eligibility
  validate :validate_word_count
  validate :policy_agreement

  accepts_nested_attributes_for :contact, allow_destroy: true,reject_if: -> (attrs) { attrs['kind'].present? }
  accepts_nested_attributes_for :alternate_billing_contact, allow_destroy: true, reject_if: -> (attrs) { attrs['kind'].present? }

  accepts_nested_attributes_for :billing_request, reject_if: -> (attrs) { attrs['kind'].present? }
  accepts_nested_attributes_for :customization_request, reject_if: -> (attrs) { attrs['kind'].present? }
  accepts_nested_attributes_for :note, reject_if: -> (attrs) { attrs['kind'].present? }

  around_save :create_history

  def build_nested_attributes_associations
    self.build_contact unless self.contact
    self.build_alternate_billing_contact unless self.alternate_billing_contact
    self.build_billing_request unless self.billing_request
    self.build_customization_request unless self.customization_request
    self.build_note unless self.note
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

  def word_count
    profile&.scan(/\w+/).size || 0
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
    self.organization = Organization.create_with(name: self.name).find_or_initialize_by(domain: self.contact&.email&.split(?@, 2).last)
  end

  def to_h_for_history
    {
      "conference_id" => conference&.id,
      "contact" => contact&.as_json&.slice("id", "name", "email", "organization", "unit", "address"),
      "alternate_billing_contact" => alternate_billing_contact&.as_json&.slice("id", "name", "email", "organization", "unit", "address"),
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
      "note" => note&.body,
      "policy_agreement" => policy_agreement,
    }
  end

  private 

  def validate_correct_plan
    if plan && plan.conference_id != self.conference_id
      errors.add :plan, "can't have a plan for an another conference"
    end
  end

  def validate_plan_availability
    if plan && plan_id_changed? && !plan.available?
      errors.add :plan, :sold_out
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
    if limit  && word_count > limit
      errors.add :profile, :too_long, maximum: (plan.words_limit || 0)
    end
  end

  def create_history
    yield
    editing_histories.create!(
      raw: self.to_h_for_history,
    )
  end
end
