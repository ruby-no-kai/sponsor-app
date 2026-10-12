# typed: strict
# frozen_string_literal: true

class Staff < ApplicationRecord
  validates :login, presence: true
  validates :name, presence: true
  validates :uid, presence: true

  serialize :restricted_repos, coder: JSON

  # Whether access is limited to some conferences.
  #: () -> bool
  def restricted? = !restricted_repos.nil?
end
