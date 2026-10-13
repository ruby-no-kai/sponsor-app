# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "GET /auth/github/callback", type: :request do
  let(:staff_repo) { 'ruby-no-kai/staff-repo' }
  let(:restricted_repo) { 'ruby-no-kai/rubykaigi.org' }
  let(:pull_only) { {admin: false, maintain: false, push: false, triage: false, pull: true} }
  let(:triage) { {admin: false, maintain: false, push: false, triage: true, pull: true} }
  let(:push) { {admin: false, maintain: false, push: true, triage: true, pull: true} }
  let(:staff) { Staff.find_by!(uid: '12345') }

  around do |example|
    original_repo = Rails.application.config.x.github.repo
    Rails.application.config.x.github.repo = staff_repo
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: 'github',
      uid: '12345',
      info: {name: 'Octo Cat', nickname: 'octocat', image: 'https://avatars.invalid/octocat.png'},
      credentials: {token: 'gho_dummy'},
    )
    example.run
  ensure
    OmniAuth.config.mock_auth.delete(:github)
    OmniAuth.config.test_mode = false
    Rails.application.config.x.github.repo = original_repo
  end

  def stub_repo(name, permissions)
    stub_request(:get, "https://api.github.com/repos/#{name}").to_return(
      status: 200,
      headers: {'Content-Type' => 'application/json'},
      body: JSON.generate(full_name: name, private: false, permissions:),
    )
  end

  def stub_repo_not_found(name)
    stub_request(:get, "https://api.github.com/repos/#{name}").to_return(
      status: 404,
      headers: {'Content-Type' => 'application/json'},
      body: JSON.generate(message: 'Not Found'),
    )
  end

  def create_restricted_conference
    FactoryBot.create(:conference, allow_restricted_access: true, github_repo: "#{restricted_repo}@main:data/sponsors.yml")
  end

  context "with push permission on the staff repo" do
    before { stub_repo(staff_repo, push) }

    it "signs in as unrestricted staff" do
      get '/auth/github/callback'
      expect(response).to redirect_to('/')
      expect(staff.restricted_repos).to be_nil
    end
  end

  context "with admin permission on the staff repo" do
    before { stub_repo(staff_repo, {admin: true, maintain: true, push: true, triage: true, pull: true}) }

    it "signs in as unrestricted staff" do
      get '/auth/github/callback'
      expect(response).to redirect_to('/')
      expect(staff.restricted_repos).to be_nil
    end
  end

  context "with only pull permission on a public staff repo" do
    before { stub_repo(staff_repo, pull_only) }

    it "rejects the sign in" do
      get '/auth/github/callback'
      expect(response).to have_http_status(:forbidden)
      expect(Staff.find_by(uid: '12345')).to be_nil
    end
  end

  context "with triage permission on the staff repo" do
    before { stub_repo(staff_repo, triage) }

    it "rejects the sign in" do
      get '/auth/github/callback'
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "with a repo response lacking permissions" do
    before { stub_repo(staff_repo, nil) }

    it "rejects the sign in" do
      get '/auth/github/callback'
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "with only pull permission on a public restricted-access conference repo" do
    before do
      create_restricted_conference
      stub_repo_not_found(staff_repo)
      stub_repo(restricted_repo, pull_only)
    end

    it "rejects the sign in" do
      get '/auth/github/callback'
      expect(response).to have_http_status(:forbidden)
      expect(Staff.find_by(uid: '12345')).to be_nil
    end
  end

  context "with push permission on a restricted-access conference repo" do
    before do
      create_restricted_conference
      stub_repo_not_found(staff_repo)
      stub_repo(restricted_repo, push)
    end

    it "signs in as staff restricted to the repo" do
      get '/auth/github/callback'
      expect(response).to redirect_to('/')
      expect(staff.restricted_repos).to eq([restricted_repo])
    end
  end

  context "with an unsupported provider" do
    around do |example|
      Rails.application.env_config['omniauth.auth'] = OmniAuth::AuthHash.new(provider: 'developer', uid: '12345', info: {name: 'Octo Cat'})
      example.run
    ensure
      Rails.application.env_config.delete('omniauth.auth')
    end

    it "responds not found without signing in" do
      get '/auth/developer/callback'
      expect(response).to have_http_status(:not_found)
      expect(Staff.find_by(uid: '12345')).to be_nil
    end
  end

  describe "GET /admin/session/new" do
    it "remembers a path on this site to return to after GitHub sign-in" do
      get '/admin/session/new', params: {proceed: 1, back_to: '/admin/conferences/rk26'}

      expect(response).to redirect_to('/auth/github')
      expect(session[:back_to]).to eq('/admin/conferences/rk26')
    end

    it "forgets a back_to that leads off-site" do
      get '/admin/session/new', params: {proceed: 1, back_to: '//evil.invalid/'}

      expect(session[:back_to]).to be_nil
    end
  end

  describe "the development backdoor" do
    before { allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('development')) }

    it "carries back_to into its form" do
      get '/admin/session/new', params: {back_to: '/admin/conferences/rk26'}

      expect(response.body).to include('<input type="hidden" name="back_to" id="back_to" value="/admin/conferences/rk26"')
    end

    it "signs in and returns to a path on this site" do
      post '/admin/session/backdoor', params: {login: 'dev', back_to: '/admin/conferences/rk26?tab=plans'}

      expect(response).to redirect_to('/admin/conferences/rk26?tab=plans')
      expect(session[:staff_id]).to eq(Staff.find_by!(login: 'dev').id)
    end

    it "signs in without back_to" do
      post '/admin/session/backdoor', params: {login: 'dev'}

      expect(response).to redirect_to('/')
    end

    ['//evil.invalid/', '///evil.invalid/', 'https://evil.invalid/', 'javascript:alert(1)', 'admin', ''].each do |back_to|
      it "returns to the top page for back_to #{back_to.inspect}" do
        post '/admin/session/backdoor', params: {login: 'dev', back_to:}

        expect(response).to redirect_to('/')
      end
    end

    it "is not found outside development" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('test'))

      post '/admin/session/backdoor', params: {login: 'dev', back_to: '/admin'}

      expect(response).to have_http_status(:not_found)
    end
  end
end
