# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Announcements", type: :request do
  let(:conference) { FactoryBot.create(:conference) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "GET index" do
    it "lists announcements grouped by issue" do
      FactoryBot.create(:announcement, conference:, issue: 'plain', locale: 'en', title: 'Plain EN')
      FactoryBot.create(:announcement, conference:, issue: 'plain', locale: 'ja', title: 'Plain JA')
      FactoryBot.create(:announcement, :pinned, conference:, issue: 'pinned', title: 'Pinned EN')

      get conference_announcements_path(conference)

      expect(response).to have_http_status(:ok)
      expect(response.body.index('Pinned EN')).to be < response.body.index('Plain EN')
      expect(response.body).to include('Plain JA')
    end
  end

  describe "GET new" do
    it "prefills the issue" do
      get new_conference_announcement_path(conference, issue: 'existing-issue')
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('existing-issue')
    end
  end

  describe "POST create" do
    it "creates an announcement by the current staff" do
      expect do
        post conference_announcements_path(conference), params: {announcement: {issue: 'new-issue', locale: 'en', title: 'Hello', body: 'World', stickiness: 0}}
      end.to change(conference.announcements, :count).by(1)

      announcement = conference.announcements.last
      expect(announcement.staff).to eq(staff)
      expect(response).to redirect_to(conference_announcement_path(conference, announcement))
    end
  end

  describe "existing announcement" do
    let!(:announcement) { FactoryBot.create(:announcement, conference:, title: 'Original') }

    it "shows the announcement" do
      get conference_announcement_path(conference, announcement)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Original')
    end

    it "updates the announcement" do
      patch conference_announcement_path(conference, announcement), params: {announcement: {title: 'Changed'}}

      expect(response).to redirect_to(conference_announcement_path(conference, announcement))
      expect(announcement.reload.title).to eq('Changed')
    end
  end
end
