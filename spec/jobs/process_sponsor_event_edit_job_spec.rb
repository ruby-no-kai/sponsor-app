require 'rails_helper'

RSpec.describe ProcessSponsorEventEditJob, type: :job do
  let(:conference) { FactoryBot.create(:conference, :full, github_repo: 'ruby-no-kai/rubykaigi.org@main:data/sponsors.yml', github_repo_images_path: 'images') }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }

  before do
    Rails.application.config.x.public_url_host = 'test.host'
    allow(SlackWebhookJob).to receive(:perform_now)
    allow(GenerateSponsorsYamlFileJob).to receive(:perform_now)
    allow(PushEventAssetFileJob).to receive(:perform_later)
  end

  describe 'PushEventAssetFileJob trigger' do
    context 'when asset_file_id changes (new file)' do
      it 'triggers PushEventAssetFileJob' do
        event = FactoryBot.create(:sponsor_event, :accepted, sponsorship:)
        asset_file = FactoryBot.create(:sponsor_event_asset_file, sponsorship:, sponsor_event: event)
        event.reload

        # Simulate a save that records the asset_file_id change
        event.touch
        edit = event.last_editing_history

        described_class.perform_now(edit)

        expect(PushEventAssetFileJob).to have_received(:perform_later).with(edit)
      end
    end

    context 'when asset_file_checksum_sha256 changes (in-place replacement)' do
      it 'triggers PushEventAssetFileJob' do
        asset_file = FactoryBot.create(:sponsor_event_asset_file, sponsorship:, checksum_sha256: 'old_checksum')
        event = FactoryBot.create(:sponsor_event, :accepted, sponsorship:, asset_file:)
        event.reload

        # Update checksum and trigger new history
        asset_file.update!(checksum_sha256: 'new_checksum')
        event.touch
        edit = event.last_editing_history

        described_class.perform_now(edit)

        expect(PushEventAssetFileJob).to have_received(:perform_later).with(edit)
      end
    end

    context 'when status changes to accepted and event has asset_file' do
      it 'triggers PushEventAssetFileJob' do
        asset_file = FactoryBot.create(:sponsor_event_asset_file, sponsorship:)
        event = FactoryBot.create(:sponsor_event, :pending, sponsorship:, asset_file:)
        event.reload

        event.update!(status: :accepted)
        edit = event.last_editing_history

        described_class.perform_now(edit)

        expect(PushEventAssetFileJob).to have_received(:perform_later).with(edit)
      end
    end

    context 'when asset_file_id changes to nil (removal)' do
      it 'does not trigger PushEventAssetFileJob' do
        asset_file = FactoryBot.create(:sponsor_event_asset_file, sponsorship:)
        event = FactoryBot.create(:sponsor_event, :accepted, sponsorship:, asset_file:)
        event.reload

        # Destroy the asset file (simulating removal) and trigger new history
        asset_file.destroy!
        event.reload
        event.touch
        edit = event.last_editing_history

        described_class.perform_now(edit)

        expect(PushEventAssetFileJob).not_to have_received(:perform_later).with(edit)
      end
    end

    context 'when event is not accepted with asset file changes' do
      it 'does not trigger PushEventAssetFileJob' do
        event = FactoryBot.create(:sponsor_event, :pending, sponsorship:)
        asset_file = FactoryBot.create(:sponsor_event_asset_file, sponsorship:, sponsor_event: event)
        event.reload

        event.touch
        edit = event.last_editing_history

        described_class.perform_now(edit)

        expect(PushEventAssetFileJob).not_to have_received(:perform_later).with(edit)
      end
    end
  end
end
