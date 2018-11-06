class Contact < ApplicationRecord
  # Trust the foreign key: https://github.com/rails/rails/issues/25198
  belongs_to :sponsorship, optional: true
  enum kind: %i(primary billing)

  validates :kind, presence: true
  validates :email, presence: true
  validates :address, presence: true
  validates :name, presence: true

  attr_writer :_keep

  def _keep
    return @_keep if defined? @_keep
    @_keep = self.persisted?
  end
end
