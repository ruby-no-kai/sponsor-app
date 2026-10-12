# typed: strict
# frozen_string_literal: true

class SponsorshipStaffNote < ApplicationRecord
  include MarkdownBody

  belongs_to :sponsorship
  belongs_to :staff

  #: () -> bool
  def pin?
    stickiness > 0
  end
end
