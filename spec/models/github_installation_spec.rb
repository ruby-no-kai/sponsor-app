# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GithubInstallation do
  let(:app_id) { '12345' }
  let(:private_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:repo_name) { 'owner/repo' }
  let(:installation_id) { 42 }
  let(:access_token) { 'ghs_test_token' }

  before do
    allow(Rails.application.config.x.github).to receive_messages(app_id: app_id, private_key: private_key)
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
        .and_return({id: installation_id})
      allow(app_client).to receive(:create_app_installation_access_token)
        .with(installation_id, accept: GithubInstallation::GITHUB_MEDIA_TYPE)
        .and_return({token: access_token})

      installation = described_class.new(repo_name)
      expect(installation.octokit).to eq(repo_client)
    end
  end

  describe 'JWT creation' do
    it 'creates JWT with correct payload' do
      now = Time.now.to_i
      allow(Time).to receive(:now).and_return(Time.zone.at(now))

      allow(JWT).to receive(:encode).with(
        {iss: app_id, iat: now, exp: now + 180},
        private_key,
        'RS256',
      ).and_return('test_jwt')

      app_client = instance_double(Octokit::Client)
      repo_client = instance_double(Octokit::Client)

      allow(Octokit::Client).to receive(:new).with(bearer_token: 'test_jwt').and_return(app_client)
      allow(Octokit::Client).to receive(:new).with(access_token: access_token).and_return(repo_client)

      allow(app_client).to receive_messages(find_repository_installation: {id: installation_id}, create_app_installation_access_token: {token: access_token})

      installation = described_class.new(repo_name)
      installation.octokit

      expect(JWT).to have_received(:encode).with(
        {iss: app_id, iat: now, exp: now + 180},
        private_key,
        'RS256',
      )
    end
  end

  describe 'installation token' do
    it 'finds repository installation and creates access token' do
      app_client = instance_double(Octokit::Client)
      repo_client = instance_double(Octokit::Client)

      allow(Octokit::Client).to receive(:new).with(bearer_token: kind_of(String)).and_return(app_client)
      allow(Octokit::Client).to receive(:new).with(access_token: access_token).and_return(repo_client)

      allow(app_client).to receive(:find_repository_installation)
        .with(repo_name, accept: GithubInstallation::GITHUB_MEDIA_TYPE)
        .and_return({id: installation_id})
      allow(app_client).to receive(:create_app_installation_access_token)
        .with(installation_id, accept: GithubInstallation::GITHUB_MEDIA_TYPE)
        .and_return({token: access_token})

      installation = described_class.new(repo_name)
      installation.octokit

      expect(app_client).to have_received(:find_repository_installation)
        .with(repo_name, accept: GithubInstallation::GITHUB_MEDIA_TYPE)
      expect(app_client).to have_received(:create_app_installation_access_token)
        .with(installation_id, accept: GithubInstallation::GITHUB_MEDIA_TYPE)
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

      allow(app_client).to receive_messages(find_repository_installation: {id: installation_id}, create_app_installation_access_token: {token: access_token})

      allow(repo_client).to receive(:repository)
        .with(repo_name)
        .and_return({default_branch: 'main'})

      installation = described_class.new(repo_name)
      expect(installation.base_branch).to eq('main')
      expect(repo_client).to have_received(:repository).with(repo_name)
    end
  end
end
