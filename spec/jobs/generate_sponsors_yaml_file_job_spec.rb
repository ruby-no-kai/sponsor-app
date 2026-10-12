# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateSponsorsYamlFileJob, type: :job do
  let(:conference) { FactoryBot.create(:conference, github_repo: 'ruby-no-kai/rubykaigi.org@main:data/sponsors.yml') }
  let(:plan) { FactoryBot.create(:plan, conference:, name: 'Ruby Sponsor') }
  let!(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, accepted_at: Time.current) }

  def run_job
    described_class.new.tap { |job| job.perform(conference, push: false) }
  end

  describe '#data' do
    it 'groups sponsors with presence by base plan and plan name' do
      entry = run_job.data.fetch('ruby_sponsor')

      expect(entry[:base_plan]).to eq('ruby sponsor')
      expect(entry[:plans].fetch('ruby_sponsor')[:plan_name]).to eq('Ruby Sponsor')
      expect(entry[:plans].fetch('ruby_sponsor')[:sponsors].map { |s| s[:id] }).to eq([sponsorship.id])
    end

    it 'returns nil without sponsors with presence' do
      sponsorship.update!(withdrawn_at: Time.current)

      expect(run_job.data).to be_nil
    end
  end

  describe '#push_to_github' do
    let(:pusher) { instance_double(GenerateSponsorsYamlFileJob::GitHubPusher, push: nil) }

    before do
      allow(GenerateSponsorsYamlFileJob::GitHubPusher).to receive(:new).and_return(pusher)
    end

    it 'pushes the YAML to the repository path' do
      job = run_job
      job.push_to_github

      expect(GenerateSponsorsYamlFileJob::GitHubPusher).to have_received(:new).with(
        hash_including(
          conference:,
          filepath: 'data/sponsors.yml',
          content: job.yaml_data,
          last_editing_history_id: sponsorship.last_editing_history&.id,
        ),
      )
      expect(pusher).to have_received(:push)
    end

    it 'does nothing without a GitHub repository' do
      conference.update!(github_repo: nil)

      run_job.push_to_github

      expect(GenerateSponsorsYamlFileJob::GitHubPusher).not_to have_received(:new)
    end
  end

  describe GenerateSponsorsYamlFileJob::GitHubPusher do
    subject(:pusher) do
      described_class.new(
        conference:,
        filepath: 'data/sponsors.yml',
        content: "# last_editing_history: 5, last_event_editing_history: 0\n",
        last_editing_history_id: 5,
        last_event_editing_history_id: nil,
        push_id: 5,
      )
    end

    let(:branch) { "sponsor-app/#{conference.slug}" }
    let(:title) { "Update sponsors.yml for #{conference.slug} (5)" }
    let(:octokit) { instance_double(Octokit::Client) }
    let(:installation) { instance_double(GithubInstallation, octokit:, base_branch: 'main') }

    before do
      allow(GithubInstallation).to receive(:new).and_return(installation)
      allow(octokit).to receive(:contents).and_raise(Octokit::NotFound)
      allow(octokit).to receive(:branch).with('ruby-no-kai/rubykaigi.org', branch).and_raise(Octokit::NotFound)
      allow(octokit).to receive(:branch).with('ruby-no-kai/rubykaigi.org', 'main').and_return({commit: {sha: 'abc'}})
      allow(octokit).to receive(:create_ref)
      allow(octokit).to receive(:update_contents)
      allow(octokit).to receive(:pull_requests).and_return([])
      allow(octokit).to receive(:create_pull_request)
    end

    it 'commits the content to a branch and opens a pull request' do
      pusher.push

      expect(GithubInstallation).to have_received(:new).with('ruby-no-kai/rubykaigi.org', branch: 'main')
      expect(octokit).to have_received(:create_ref).with('ruby-no-kai/rubykaigi.org', "refs/heads/#{branch}", 'abc')
      expect(octokit).to have_received(:update_contents).with('ruby-no-kai/rubykaigi.org', 'data/sponsors.yml', title, nil, anything, branch:)
      expect(octokit).to have_received(:create_pull_request).with('ruby-no-kai/rubykaigi.org', 'main', branch, title, nil)
    end

    it 'does nothing without a GitHub repository' do
      conference.update!(github_repo: nil)

      pusher.push

      expect(GithubInstallation).not_to have_received(:new)
    end
  end
end
