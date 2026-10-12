# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Conferences", type: :request do
  let(:conference) { FactoryBot.create(:conference, github_repo: 'ruby-no-kai/rubykaigi.org@master:data', allow_restricted_access: true) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "GET show" do
    it "shows plans with their sponsorship counts" do
      conference = FactoryBot.create(:conference, :full)
      plan = conference.plans.first
      FactoryBot.create(:sponsorship, conference:, plan:)

      get conference_path(conference)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("(1/#{plan.capacity})")
    end
  end

  describe "GET table_view" do
    it "lists sponsorships" do
      conference = FactoryBot.create(:conference, :full)
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first)

      get table_view_conference_path(conference)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(sponsorship.name)
    end
  end

  describe "GET asset_urls" do
    it "lists asset file names and download URLs" do
      conference = FactoryBot.create(:conference, :full)
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first)
      allow(Aws::S3::Client).to receive(:new).and_return(instance_double(Aws::S3::Client))
      presigner = instance_double(Aws::S3::Presigner, presigned_url: 'https://s3.example.com/presigned')
      allow(Aws::S3::Presigner).to receive(:new).and_return(presigner)

      get asset_urls_conference_path(conference)

      expect(response.parsed_body).to eq('files' => [[sponsorship.asset_file.filename, 'https://s3.example.com/presigned']])
    end
  end

  describe "GET sponsors_yml and sponsors_json" do
    it "renders the generated sponsor data" do
      job = instance_double(GenerateSponsorsYamlFileJob, perform_now: nil, yaml_data: "--- yaml\n", json_data: '{"json":1}')
      allow(GenerateSponsorsYamlFileJob).to receive(:new).with(conference, push: false).and_return(job)

      get sponsors_yml_conference_path(conference)
      expect(response.body).to eq("--- yaml\n")

      get sponsors_json_conference_path(conference)
      expect(response.body).to eq('{"json":1}')
    end
  end

  describe "PATCH update" do
    it "updates the conference" do
      patch conference_path(conference), params: {conference: {name: 'Renamed'}}

      expect(response).to redirect_to(conference_url(conference))
      expect(conference.reload.name).to eq('Renamed')
    end

    context "with a restricted staff" do
      let(:staff) { FactoryBot.create(:staff, restricted_repos: ['org/repo']) }
      let(:conference) { FactoryBot.create(:conference, allow_restricted_access: true, github_repo: 'org/repo@main:data') }

      it "keeps restricted access allowed" do
        patch conference_path(conference), params: {conference: {allow_restricted_access: '0'}}

        expect(response).to redirect_to(conference_url(conference))
        expect(conference.reload.allow_restricted_access).to be(true)
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the conference" do
      delete conference_path(conference)
      expect(response).to redirect_to(conferences_url)
      expect(Conference.exists?(conference.id)).to be(false)
    end

    context "with restricted staff authorized for the conference" do
      let(:staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi.org']) }

      it "is forbidden" do
        delete conference_path(conference)
        expect(response).to have_http_status(:forbidden)
        expect(Conference.exists?(conference.id)).to be(true)
      end
    end
  end
end
