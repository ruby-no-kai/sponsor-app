class Sponsorship < ApplicationRecord
  belongs_to :conference
  belongs_to :organization
  belongs_to :plan, optional: true

  has_many :contacts
  has_one :contact, -> { where(kind: :primary) }, class_name: 'Contact'
  has_one :alternate_billing_contact, -> { where(kind: :billing) }, class_name: 'Contact'

  has_many :requests, class_name: 'SponsorshipRequest'
  has_one :billing_request, -> { where(kind: :billing) }, class_name: 'SponsorshipRequest'
  has_one :customization_request, -> { where(kind: :customization) }, class_name: 'SponsorshipRequest'
  has_one :note, -> { where(kind: :note) }, class_name: 'SponsorshipRequest'

  has_one :asset_file, class_name: 'SponsorshipAssetFile'
  def asset_file_id; self.asset_file&.id; end
  def asset_file_id=(other)
    self.asset_file = SponsorshipAssetFile.find_by(id: other.to_i)
  end

  validates :organization, presence: true, uniqueness: true

  validates :contact, presence: true

  validates :name, presence: true
  validates :url, presence: true
  validates :profile, presence: true

  validates :asset_file, presence: true

  validate :validate_correct_plan
  validate :policy_agreement

  accepts_nested_attributes_for :contact, allow_destroy: true,reject_if: -> (attrs) { attrs['kind'].present? }
  accepts_nested_attributes_for :alternate_billing_contact, allow_destroy: true, reject_if: -> (attrs) { attrs['kind'].present? }

  accepts_nested_attributes_for :billing_request, reject_if: -> (attrs) { attrs['kind'].present? }
  accepts_nested_attributes_for :customization_request, reject_if: -> (attrs) { attrs['kind'].present? }
  accepts_nested_attributes_for :note, reject_if: -> (attrs) { attrs['kind'].present? }

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

  def plan_name
    customized? ? (customization_name || plan&.name) : plan&.name
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

  private 

  def validate_correct_plan
    if plan && plan.conference_id != self.conference_id
      errors.add :plan, "can't have a plan for an another conference"
    end
  end

  def validate_policy_agreement
    if !policy_agreement
      errors.add :policy_agreement, "must agree with the policy"
    end
  end
end
