class SponsorshipStaffNote < ApplicationRecord
  include MarkdownBody

  belongs_to :sponsorship
  belongs_to :staff

  def pin?
    stickiness > 0
  end
end
