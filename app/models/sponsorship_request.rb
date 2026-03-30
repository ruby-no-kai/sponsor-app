# frozen_string_literal: true

class SponsorshipRequest < ApplicationRecord
  # Trust the foreign key: https://github.com/rails/rails/issues/25198
  belongs_to :sponsorship, optional: true

  enum :kind, {billing: 0, customization: 1, note: 2}

  validates :kind, presence: true
end
