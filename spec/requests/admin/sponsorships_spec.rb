# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Sponsorships", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
    allow(ProcessSponsorshipEditJob).to receive(:perform_later)
  end

  describe "GET show" do
    it "shows the sponsorship with its staff notes" do
      SponsorshipStaffNote.create!(sponsorship:, staff:, body: 'Pinned note', stickiness: 1)

      get conference_sponsorship_path(conference, sponsorship)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Pinned note')
    end
  end

  describe "GET edit" do
    it "renders the form" do
      get edit_conference_sponsorship_path(conference, sponsorship)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET editing_histories" do
    it "lists the edits of the sponsorship" do
      get conference_sponsorship_editing_histories_path(conference, sponsorship)
      expect(response).to have_http_status(:ok)
    end

    it "shows the new value of a change or an addition, and the old value of a removal" do
      SponsorshipEditingHistory.create!(
        sponsorship:,
        raw: {'title' => 'New'},
        diff: [['~', 'title', 'Old', 'New'], ['+', 'link_name', 'Join'], ['-', 'withdrawn_at', '2026-06-01T09:00:00.000Z']],
      )

      get conference_sponsorship_editing_histories_path(conference, sponsorship)

      rows = Nokogiri::HTML(response.body).css('tbody tr').map { |tr| tr.css('td').map(&:text) }
      expect(rows).to include(
        ['~', '"title"', '"New"'],
        ['+', '"link_name"', '"Join"'],
        ['-', '"withdrawn_at"', '"2026-06-01T09:00:00.000Z"'],
      )
    end
  end

  describe "GET download_asset" do
    it "redirects to the asset download URL" do
      allow(Aws::S3::Client).to receive(:new).and_return(instance_double(Aws::S3::Client))
      presigner = instance_double(Aws::S3::Presigner, presigned_url: 'https://s3.example.com/presigned')
      allow(Aws::S3::Presigner).to receive(:new).and_return(presigner)

      get download_asset_conference_sponsorship_path(conference, sponsorship)

      expect(response).to redirect_to('https://s3.example.com/presigned')
    end
  end

  describe "PATCH update" do
    it "updates the sponsorship as the current staff" do
      patch conference_sponsorship_path(conference, sponsorship), params: {sponsorship: {name: 'Renamed'}}

      expect(response).to redirect_to(conference_sponsorship_path(conference, sponsorship))
      expect(sponsorship.reload.name).to eq('Renamed')
      history = sponsorship.editing_histories.reorder(:id).last
      expect(history.staff).to eq(staff)
      expect(ProcessSponsorshipEditJob).to have_received(:perform_later).with(history)
    end
  end

  describe "DELETE destroy" do
    it "withdraws the sponsorship as the current staff" do
      delete conference_sponsorship_path(conference, sponsorship)

      expect(response).to redirect_to(conference_sponsorship_path(conference, sponsorship))
      expect(sponsorship.reload).to be_withdrawn
      expect(sponsorship.editing_histories.reorder(:id).last.staff).to eq(staff)
    end

    it "responds not found for a withdrawn sponsorship" do
      sponsorship.withdraw.save!

      delete conference_sponsorship_path(conference, sponsorship)

      expect(response).to have_http_status(:not_found)
    end
  end
end
