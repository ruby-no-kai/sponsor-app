# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::AdminSponsorEventResource do
  it 'maps every status of SponsorEvent to its own SponsorEventStatus value' do
    statuses = Rk::SponsorApp::SponsorEventStatus.descriptor.map { |name, _number| name } - [:SPONSOR_EVENT_STATUS_UNSPECIFIED]

    expect(described_class::STATUSES.keys).to match_array(SponsorEvent.statuses.keys)
    expect(described_class::STATUSES.values).to match_array(statuses)
  end
end
