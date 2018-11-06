class Organization < ApplicationRecord
  has_many :sponsorships
  validates :name, presence: true
  validates :domain, presence: true
end
