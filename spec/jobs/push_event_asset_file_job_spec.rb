require 'rails_helper'

RSpec.describe PushEventAssetFileJob, type: :job do
  let(:conference) { FactoryBot.create(:conference, :full, github_repo: 'ruby-no-kai/rubykaigi.org@main:data/sponsors.yml', github_repo_images_path: 'images') }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }
  let(:event) { FactoryBot.create(:sponsor_event, :accepted, sponsorship:) }
  let(:asset_file) { FactoryBot.create(:sponsor_event_asset_file, sponsorship:, sponsor_event: event) }
  let(:editing_history) do
    event.reload
    event.last_editing_history
  end

  let(:test_image_data) { File.binread(Rails.root.join('spec/fixtures/files/test_image.png')) }

  let(:octokit) { instance_double(Octokit::Client) }
  let(:gh_installation) { instance_double(GithubInstallation, octokit:, base_branch: 'main') }

  before do
    Rails.application.config.x.public_url_host = 'test.host'

    asset_file # ensure asset_file is created and associated
    event.reload # reload to pick up has_one association

    allow(GithubInstallation).to receive(:new).and_return(gh_installation)

    allow_any_instance_of(SponsorEventAssetFile).to receive(:get_object) do |_asset_file, **args|
      args[:response_target].write(test_image_data) if args[:response_target]
    end

    allow(octokit).to receive(:delete_branch)
    allow(octokit).to receive(:branch).and_return({ commit: { sha: 'abc123' } })
    allow(octokit).to receive(:create_ref)
    allow(octokit).to receive(:contents).and_raise(Octokit::NotFound.new)
    allow(octokit).to receive(:update_contents)
    allow(octokit).to receive(:create_pull_request)
  end

  describe 'record resolution' do
    it 'accepts a SponsorEvent and uses its last editing history' do
      described_class.perform_now(event)

      expect(octokit).to have_received(:create_pull_request).with(
        anything, anything,
        a_string_including(editing_history.id.to_s),
        anything, anything,
      )
    end

    it 'accepts a SponsorEventAssetFile and uses its event last editing history' do
      described_class.perform_now(asset_file)

      expect(octokit).to have_received(:create_pull_request).with(
        anything, anything,
        a_string_including(editing_history.id.to_s),
        anything, anything,
      )
    end

    it 'raises ArgumentError for SponsorEventAssetFile without sponsor_event' do
      detached = FactoryBot.create(:sponsor_event_asset_file, sponsorship:, sponsor_event: nil)
      expect { described_class.perform_now(detached) }.to raise_error(ArgumentError, /no associated sponsor_event/)
    end

    it 'raises ArgumentError for unsupported record types' do
      expect { described_class.perform_now(conference) }.to raise_error(ArgumentError, /expected SponsorEventEditingHistory/)
    end
  end

  describe 'guard conditions' do
    it 'returns early when github_repo_images_path is blank' do
      conference.update!(github_repo_images_path: nil)
      described_class.perform_now(editing_history)
      expect(octokit).not_to have_received(:create_pull_request)
    end

    it 'returns early when github_repo is nil' do
      conference.update!(github_repo: nil)
      described_class.perform_now(editing_history)
      expect(octokit).not_to have_received(:create_pull_request)
    end

    it 'returns early when event is not accepted' do
      event.update!(status: :pending)
      described_class.perform_now(editing_history)
      expect(octokit).not_to have_received(:create_pull_request)
    end

    it 'returns early when event has no asset file' do
      ev = FactoryBot.create(:sponsor_event, :accepted, sponsorship:)
      edit = ev.last_editing_history

      described_class.perform_now(edit)
      expect(octokit).not_to have_received(:create_pull_request)
    end
  end

  describe 'image conversion' do
    it 'downloads image from S3 via asset_file.get_object with response_target' do
      expect_any_instance_of(SponsorEventAssetFile).to receive(:get_object).with(response_target: an_instance_of(File)) do |_asset_file, **args|
        args[:response_target].write(test_image_data)
      end
      described_class.perform_now(editing_history)
    end

    it 'converts image to webp using vipsthumbnail' do
      described_class.perform_now(editing_history)

      expect(octokit).to have_received(:update_contents) do |_repo, _path, _msg, _sha, content, **_opts|
        expect(content[0..3]).to eq("RIFF")
        expect(content[8..11]).to eq("WEBP")
      end
    end

    it 'cleans up temp directory on success' do
      job = described_class.new(editing_history)
      job.perform_now
      tmpdir = Rails.root.join('tmp', "PushEventAssetFileJob-#{job.job_id}-#{asset_file.id}")
      expect(Dir.exist?(tmpdir)).to be false
    end

    it 'raises on vipsthumbnail failure' do
      allow(Open3).to receive(:capture3).and_return(['', 'error message', double(success?: false, exitstatus: 1)])
      expect { described_class.perform_now(editing_history) }.to raise_error(/vipsthumbnail failed/)
    end
  end

  describe 'GitHub push' do
    it 'creates branch from base branch HEAD' do
      described_class.perform_now(editing_history)

      expect(octokit).to have_received(:branch).with('ruby-no-kai/rubykaigi.org', 'main')
      expect(octokit).to have_received(:create_ref).with(
        'ruby-no-kai/rubykaigi.org',
        "refs/heads/sponsor-app/event-asset/#{sponsorship.id}-#{event.id}/#{editing_history.id}",
        'abc123'
      )
    end

    it 'commits webp at correct path' do
      described_class.perform_now(editing_history)

      expected_path = "images/events/#{sponsorship.id}-#{event.id}.webp"
      expect(octokit).to have_received(:update_contents).with(
        'ruby-no-kai/rubykaigi.org',
        expected_path,
        anything,
        nil,
        anything,
        branch: "sponsor-app/event-asset/#{sponsorship.id}-#{event.id}/#{editing_history.id}",
      )
    end

    it 'uses existing blob sha when file already exists on base branch' do
      allow(octokit).to receive(:contents).and_return({ sha: 'existing_blob_sha' })
      described_class.perform_now(editing_history)

      expect(octokit).to have_received(:update_contents).with(
        anything, anything, anything,
        'existing_blob_sha',
        anything,
        anything,
      )
    end

    it 'creates PR with expected title and body' do
      described_class.perform_now(editing_history)

      expected_title = "Event asset: #{sponsorship.name} [#{event.id}@#{editing_history.id}]"
      expect(octokit).to have_received(:create_pull_request).with(
        'ruby-no-kai/rubykaigi.org',
        'main',
        "sponsor-app/event-asset/#{sponsorship.id}-#{event.id}/#{editing_history.id}",
        expected_title,
        a_string_including(event.title).and(a_string_including(sponsorship.name)),
      )
    end

    it 'tries to delete existing branch before creating' do
      described_class.perform_now(editing_history)

      expect(octokit).to have_received(:delete_branch).with(
        'ruby-no-kai/rubykaigi.org',
        "sponsor-app/event-asset/#{sponsorship.id}-#{event.id}/#{editing_history.id}",
      )
    end

    it 'handles non-existent branch deletion gracefully' do
      allow(octokit).to receive(:delete_branch).and_raise(Octokit::UnprocessableEntity.new)
      expect { described_class.perform_now(editing_history) }.not_to raise_error
    end

    it 'strips trailing slash from github_repo_images_path' do
      conference.update!(github_repo_images_path: 'images/')
      described_class.perform_now(editing_history)

      expected_path = "images/events/#{sponsorship.id}-#{event.id}.webp"
      expect(octokit).to have_received(:update_contents).with(
        anything, expected_path, anything, anything, anything, anything,
      )
    end
  end
end
