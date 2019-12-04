class Contact < ApplicationRecord
  # Trust the foreign key: https://github.com/rails/rails/issues/25198
  belongs_to :sponsorship, optional: true
  enum kind: %i(primary billing)

  validates :kind, presence: true
  validates :email, presence: true
  validates :address, presence: true
  validates :name, presence: true

  validate :validate_email_ccs

  attr_writer :_keep

  def _keep
    return @_keep if defined? @_keep
    @_keep = self.persisted?
  end

  def email_ccs
    email_cc&.split(/[,;]\s*/) || []
  end

  def validate_email_ccs
    email_ccs.each do |email|
      unless email.include?('@')
        errors.add :email_cc, "is invalid"
      end
    end
  end
end
