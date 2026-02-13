require 'rails_helper'

RSpec.describe GithubInstallation do
  let(:app_id) { '12345' }
  let(:private_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:repo_name) { 'owner/repo' }
  let(:installation_id) { 42 }
  let(:access_token) { 'ghs_test_token' }

  before do
    allow(Rails.application.config.x.github).to receive(:app_id).and_return(app_id)
    allow(Rails.application.config.x.github).to receive(:private_key).and_return(private_key)
  end

  describe '#octokit' do
    it 'returns an authenticated Octokit client' do
      app_client = instance_double(Octokit::Client)
      repo_client = instance_double(Octokit::Client)

      allow(Octokit::Client).to receive(:new).and_call_original
      allow(Octokit::Client).to receive(:new).with(bearer_token: kind_of(String)).and_return(app_client)
      allow(Octokit::Client).to receive(:new).with(access_token: access_token).and_return(repo_client)

      allow(app_client).to receive(:find_repository_installation)
        .with(repo_name, accept: GithubInstallation::GITHUB_MEDIA_TYPE)
        .and_return({ id: installation_id })
      allow(app_client).to receive(:create_app_installation_access_token)
        .with(installation_id, accept: GithubInstallation::GITHUB_MEDIA_TYPE)
        .and_return({ token: access_token })

      installation = described_class.new(repo_name)
      expect(installation.octokit).to eq(repo_client)
    end
  end

  describe 'JWT creation' do
    it 'creates JWT with correct payload' do
      now = Time.now.to_i
      allow(Time).to receive(:now).and_return(Time.at(now))

      expect(JWT).to receive(:encode).with(
        { iss: app_id, iat: now, exp: now + 180 },
        private_key,
        'RS256',
      ).and_return('test_jwt')

      app_client = instance_double(Octokit::Client)
      repo_client = instance_double(Octokit::Client)

      allow(Octokit::Client).to receive(:new).with(bearer_token: 'test_jwt').and_return(app_client)
      allow(Octokit::Client).to receive(:new).with(access_token: access_token).and_return(repo_client)

      allow(app_client).to receive(:find_repository_installation)
        .and_return({ id: installation_id })
      allow(app_client).to receive(:create_app_installation_access_token)
        .and_return({ token: access_token })

      installation = described_class.new(repo_name)
      installation.octokit
    end
  end

  describe 'installation token' do
    it 'finds repository installation and creates access token' do
      app_client = instance_double(Octokit::Client)
      repo_client = instance_double(Octokit::Client)

      allow(Octokit::Client).to receive(:new).with(bearer_token: kind_of(String)).and_return(app_client)
      allow(Octokit::Client).to receive(:new).with(access_token: access_token).and_return(repo_client)

      expect(app_client).to receive(:find_repository_installation)
        .with(repo_name, accept: GithubInstallation::GITHUB_MEDIA_TYPE)
        .and_return({ id: installation_id })
      expect(app_client).to receive(:create_app_installation_access_token)
        .with(installation_id, accept: GithubInstallation::GITHUB_MEDIA_TYPE)
        .and_return({ token: access_token })

      installation = described_class.new(repo_name)
      installation.octokit
    end
  end

  describe '#base_branch' do
    it 'returns configured branch when present' do
      installation = described_class.new(repo_name, branch: 'production')
      expect(installation.base_branch).to eq('production')
    end

    it 'fetches default branch from GitHub when configured branch is nil' do
      app_client = instance_double(Octokit::Client)
      repo_client = instance_double(Octokit::Client)

      allow(Octokit::Client).to receive(:new).with(bearer_token: kind_of(String)).and_return(app_client)
      allow(Octokit::Client).to receive(:new).with(access_token: access_token).and_return(repo_client)

      allow(app_client).to receive(:find_repository_installation)
        .and_return({ id: installation_id })
      allow(app_client).to receive(:create_app_installation_access_token)
        .and_return({ token: access_token })

      expect(repo_client).to receive(:repository)
        .with(repo_name)
        .and_return({ default_branch: 'main' })

      installation = described_class.new(repo_name)
      expect(installation.base_branch).to eq('main')
    end
  end
end
