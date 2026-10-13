# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessSponsorshipEditJob, type: :job do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }

  before do
    allow(Rails.application.config.x).to receive(:public_url_host).and_return('test.host')
    allow(SlackWebhookJob).to receive(:perform_now)
    allow(GenerateSponsorsYamlFileJob).to receive(:perform_now)
    allow(EnsureSponsorshipTitoDiscountCodeJob).to receive(:perform_now)
  end

  it 'notifies Slack and refreshes the data derived from the sponsorship' do
    sponsorship.update!(name: 'Renamed')

    described_class.perform_now(sponsorship.last_editing_history)

    expect(SlackWebhookJob).to have_received(:perform_now).with(
      text: a_string_including('Renamed', 'edited by sponsor'),
      hook_name: :feed,
    )
    expect(GenerateSponsorsYamlFileJob).to have_received(:perform_now).with(conference)
    %w(attendee booth_staff booth_paid).each do |kind|
      expect(EnsureSponsorshipTitoDiscountCodeJob).to have_received(:perform_now).with(sponsorship, kind)
    end
  end

  it 'names the staff who made the edit' do
    staff = FactoryBot.create(:staff)
    sponsorship.staff = staff
    sponsorship.update!(name: 'Renamed')

    described_class.perform_now(sponsorship.last_editing_history)

    expect(SlackWebhookJob).to have_received(:perform_now).with(
      text: a_string_including("edited by #{staff.login} (staff)"),
      hook_name: :feed,
    )
  end
end
