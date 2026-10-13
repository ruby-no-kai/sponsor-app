# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SponsorshipWelcomeJob, type: :job do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }

  before do
    allow(Rails.application.config.x).to receive(:public_url_host).and_return('test.host')
    allow(SlackWebhookJob).to receive(:perform_now)
    allow(EnsureSponsorshipTitoDiscountCodeJob).to receive(:perform_later)
    allow(GenerateSponsorsYamlFileJob).to receive(:perform_later)
    allow(BackfillSponsorshipAssetFileChecksumJob).to receive(:perform_later)
  end

  it 'welcomes the contact and notifies the organizers' do
    expect { described_class.perform_now(sponsorship) }.to change(ActionMailer::Base.deliveries, :size).by(2)

    expect(ActionMailer::Base.deliveries.last(2).map(&:to)).to eq([[sponsorship.contact.email], [conference.contact_email_address]])
    expect(SessionToken.find_by!(email: sponsorship.contact.email).expires_at).to be > 11.months.from_now
    expect(SlackWebhookJob).to have_received(:perform_now).with(text: a_string_including(sponsorship.name))
    expect(EnsureSponsorshipTitoDiscountCodeJob).to have_received(:perform_later).with(sponsorship, 'attendee')
    expect(GenerateSponsorsYamlFileJob).to have_received(:perform_later).with(conference)
  end

  it 'backfills the checksum of an asset file without one' do
    sponsorship.asset_file.update!(checksum_sha256: '-')

    described_class.perform_now(sponsorship)

    expect(BackfillSponsorshipAssetFileChecksumJob).to have_received(:perform_later).with(sponsorship.asset_file)
  end

  it 'leaves an asset file with a checksum alone' do
    sponsorship.asset_file.update!(checksum_sha256: 'abc')

    described_class.perform_now(sponsorship)

    expect(BackfillSponsorshipAssetFileChecksumJob).not_to have_received(:perform_later)
  end
end
