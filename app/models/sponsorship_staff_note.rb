class SponsorshipStaffNote < ApplicationRecord
  belongs_to :sponsorship
  belongs_to :staff
end
