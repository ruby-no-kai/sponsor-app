# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SponsorshipStaffNote, type: :model do
  it 'requires a body that is not blank' do
    note = described_class.new(body: " \n ")

    expect(note).not_to be_valid
    expect(note.errors.details[:body]).to eq([{error: :blank}])
  end
end
