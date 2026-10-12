# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BackfillSponsorshipAssetFileChecksumJob, type: :job do
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference, :full)) }
  let(:asset_file) { sponsorship.asset_file }

  before do
    allow(Rails.application.config.x).to receive(:public_url_host).and_return('test.host')
    allow(SlackWebhookJob).to receive(:perform_now)
  end

  it 're-uploads the object with a checksum and reports the change' do
    asset_file.update!(checksum_sha256: '-')
    allow(asset_file).to receive(:get_object).and_return(double(body: StringIO.new('data'), content_type: 'image/png'))
    allow(asset_file).to receive(:put_object)
    allow(asset_file).to receive(:update_object_header) do
      asset_file.checksum_sha256 = 'new'
      asset_file
    end

    described_class.perform_now(asset_file)

    expect(asset_file).to have_received(:put_object).with(body: anything, checksum_algorithm: 'SHA256', content_type: 'image/png')
    expect(asset_file.reload.checksum_sha256).to eq('new')
    expect(SlackWebhookJob).to have_received(:perform_now).with(
      hash_including(text: a_string_including('(- → new)')),
      hook_name: 'feed',
    )
  end

  it 'raises before touching S3 for an asset file without a sponsorship' do
    detached = FactoryBot.create(:sponsorship_asset_file)
    allow(detached).to receive(:get_object)

    expect { described_class.perform_now(detached) }.to raise_error(Must::Violation)
    expect(detached).not_to have_received(:get_object)
  end
end
