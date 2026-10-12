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

  # Whether this staff member may manage the conference.
  #: (Conference) -> bool
  def conference_accessible?(conference)
    repos = restricted_repos #: Array[String]?
    return true if repos.nil?

    !!conference.allow_restricted_access && repos.include?(conference.github_repo&.name)
  end
end
