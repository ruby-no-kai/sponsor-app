# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Sponsorships", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago) }
  let(:plan) { conference.plans.first }

  describe "POST create" do
    before do
      allow(Aws::STS::Client).to receive(:new).and_return(Aws::STS::Client.new(stub_responses: true, region: 'ap-northeast-1'))
      allow(SponsorshipWelcomeJob).to receive(:perform_later)
    end

    it "stores the request locale and releases the uploaded asset file from the session" do
      post user_conference_sponsorship_asset_files_path(conference), params: {content_type: 'image/png'}
      asset_file_id = response.parsed_body.fetch('file_id').to_i

      post user_conference_sponsorship_path(conference), params: {
        hl: 'ja',
        sponsorship: {
          plan_id: plan.id,
          name: 'Contoso',
          url: 'https://contoso.invalid',
          profile: 'we are contoso',
          asset_file_id:,
          contact_attributes: {email: 'contact@contoso.invalid', address: 'addr', organization: 'Contoso', name: 'Contact'},
        },
      }

      sponsorship = Sponsorship.last
      expect(URI(response.location).path).to eq(user_conference_sponsorship_path(conference))
      expect(sponsorship.locale).to eq('ja')
      expect(sponsorship.asset_file.id).to eq(asset_file_id)
      expect(session[:asset_file_ids]).not_to include(asset_file_id)
    end
  end

  describe "GET new" do
    it "lists each fallback option with the conditions and priorities the form script reads" do
      plan.update!(name: 'Platinum')
      conference.form_description_for_locale.update!(fallback_options: Rk::SponsorApp::Internal::FallbackOptions.new(options: [
        Rk::SponsorApp::Internal::FallbackOption.new(
          value: 'platinum,gold',
          name: 'Change to Gold',
          conditions: [
            Rk::SponsorApp::Internal::FallbackOption::Condition.new(plans: ['Platinum'], booth_request: false),
            Rk::SponsorApp::Internal::FallbackOption::Condition.new(booth_request: true),
          ],
          priority_human: ['Gold', '!withdraw'],
        ),
        Rk::SponsorApp::Internal::FallbackOption.new(value: 'withdraw', name: 'Withdraw'),
      ]))

      get new_user_conference_sponsorship_path(conference)

      options = Nokogiri::HTML(response.body).css('select[name="sponsorship[fallback_option]"] option')
      expect(options.map { [it['value'], it['data-conditions'], it['data-priority-human']] }).to eq([
        ['', nil, nil],
        ['platinum,gold', '[{"plans":["Platinum"],"booth_request":false},{"booth_request":true}]', '["Gold","!withdraw"]'],
        ['withdraw', nil, nil],
      ])
    end
  end

  describe "GET show" do
    let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:) }

    it "lists the conference's published announcements" do
      FactoryBot.create(:announcement, :published, conference:, title: 'Venue map')
      FactoryBot.create(:announcement, :published, :exhibitors_only, conference:, title: 'Booth setup')
      get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)

      get user_conference_sponsorship_path(conference)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Venue map')
      expect(response.body).not_to include('Booth setup')
    end

    it "redirects to the application form without a sponsorship session" do
      get user_conference_sponsorship_path(conference)
      expect(URI(response.location).path).to eq(new_user_conference_sponsorship_path(conference))
    end
  end

  describe "PATCH update" do
    let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:) }
    let(:session_token) { FactoryBot.create(:session_token, email: sponsorship.contact.email) }

    before do
      allow(ProcessSponsorshipEditJob).to receive(:perform_later)
      get claim_user_session_path(session_token.handle)
    end

    it "stores the request locale" do
      patch user_conference_sponsorship_path(conference), params: {hl: 'ja', sponsorship: {name: 'Renamed'}}

      expect(URI(response.location).path).to eq(user_conference_sponsorship_path(conference))
      expect(sponsorship.reload.name).to eq('Renamed')
      expect(sponsorship.locale).to eq('ja')
    end
  end
end
