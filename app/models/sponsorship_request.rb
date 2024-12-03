class SponsorshipRequest < ApplicationRecord
  # Trust the foreign key: https://github.com/rails/rails/issues/25198
  belongs_to :sponsorship, optional: true

  enum :kind, %i(billing customization note)

  validates :kind, presence: true
end
