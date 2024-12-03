class Staff < ApplicationRecord
  validates :login, presence: true
  validates :name, presence: true
  validates :uid, presence: true

  serialize :restricted_repos, coder: JSON
end
