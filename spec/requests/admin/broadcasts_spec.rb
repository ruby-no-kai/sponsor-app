# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Broadcasts", type: :request do
  filter_class = Rk::SponsorApp::Internal::BroadcastRecipientFilter

  let(:conference) { FactoryBot.create(:conference) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "GET index" do
    it "lists broadcasts of the conference" do
      broadcast = FactoryBot.create(:broadcast, conference:)
      get conference_broadcasts_path(conference)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(broadcast.campaign)
    end
  end

  describe "GET new" do
    it "renders the form" do
      get new_conference_broadcast_path(conference)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST create" do
    it "creates a broadcast by the current staff and queues its deliveries" do
      allow(CreateBroadcastDeliveriesJob).to receive(:perform_later)

      expect do
        post conference_broadcasts_path(conference), params: {
          broadcast: {campaign: 'c', description: 'd', title: 't', body: 'b'},
          recipient_filter: {kind: 'raw', emails: 'someone@example.com'},
        }
      end.to change(conference.broadcasts, :count).by(1)

      broadcast = conference.broadcasts.last
      expect(broadcast).to have_attributes(staff:, status: 'created')
      expect(response).to redirect_to(conference_broadcast_path(conference, broadcast))
      expect(CreateBroadcastDeliveriesJob).to have_received(:perform_later).with(
        broadcast,
        [filter_class.new(raw: filter_class::Raw.new(emails: ['someone@example.com']))],
      )
    end

    it "leaves the plan and status of current sponsors out of the queued filter" do
      allow(CreateBroadcastDeliveriesJob).to receive(:perform_later)

      post conference_broadcasts_path(conference), params: {
        broadcast: {campaign: 'c', description: 'd', title: 't', body: 'b'},
        recipient_filter: {kind: 'all', locale: 'ja', exhibitors: '1', plan_id: '12', status: 'active'},
      }

      expect(CreateBroadcastDeliveriesJob).to have_received(:perform_later).with(
        conference.broadcasts.last,
        [filter_class.new(current_sponsors: filter_class::CurrentSponsors.new(locale: 'ja', exhibitors_only: true))],
      )
    end

    it "queues nothing to filter for none" do
      allow(CreateBroadcastDeliveriesJob).to receive(:perform_later)

      post conference_broadcasts_path(conference), params: {
        broadcast: {campaign: 'c', description: 'd', title: 't', body: 'b'},
        recipient_filter: {kind: 'none'},
      }

      expect(CreateBroadcastDeliveriesJob).to have_received(:perform_later).with(conference.broadcasts.last, [])
    end

    it "refuses an unknown filter kind without creating a broadcast" do
      allow(CreateBroadcastDeliveriesJob).to receive(:perform_later)

      expect do
        post conference_broadcasts_path(conference), params: {
          broadcast: {campaign: 'c', description: 'd', title: 't', body: 'b'},
          recipient_filter: {kind: 'everyone'},
        }
      end.not_to change(conference.broadcasts, :count)
      expect(response).to have_http_status(:bad_request)
      expect(CreateBroadcastDeliveriesJob).not_to have_received(:perform_later)
    end
  end

  describe "POST dispatch_delivery" do
    it "dispatches the broadcast as the current staff" do
      broadcast = FactoryBot.create(:broadcast, conference:, status: :ready)

      post dispatch_delivery_conference_broadcast_path(conference, broadcast)

      expect(response).to redirect_to(conference_broadcast_path(conference, broadcast))
      expect(broadcast.reload).to have_attributes(staff:, status: 'pending')
    end
  end

  describe "PATCH update" do
    let(:broadcast) { FactoryBot.create(:broadcast, conference:, status:) }
    let(:new_params) { {campaign: 'New campaign', description: 'New description', title: 'New title', body: 'New body'} }

    context "when the broadcast is not sent" do
      let(:status) { :ready }

      it "updates all attributes" do
        patch conference_broadcast_path(conference, broadcast), params: {broadcast: new_params}
        expect(response).to redirect_to(conference_broadcast_path(conference, broadcast))
        expect(broadcast.reload).to have_attributes(new_params)
      end
    end

    context "when the broadcast is sent" do
      let(:status) { :sent }

      it "rejects changes to title and body" do
        expect do
          patch conference_broadcast_path(conference, broadcast), params: {broadcast: new_params}
        end.not_to change { broadcast.reload.attributes }
      end

      it "updates campaign and description" do
        patch conference_broadcast_path(conference, broadcast), params: {broadcast: new_params.slice(:campaign, :description)}
        expect(response).to redirect_to(conference_broadcast_path(conference, broadcast))
        expect(broadcast.reload).to have_attributes(campaign: 'New campaign', description: 'New description')
      end
    end

    context "when the broadcast is sending" do
      let(:broadcast) { FactoryBot.create(:broadcast, conference:, status: :sending, body: "Hello\n\nWorld") }

      it "renders title and body disabled" do
        get edit_conference_broadcast_path(conference, broadcast)
        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/<textarea[^>]*disabled="disabled"[^>]*name="broadcast\[body\]"/)
      end

      it "updates campaign and description" do
        patch conference_broadcast_path(conference, broadcast), params: {broadcast: new_params.slice(:campaign, :description)}
        expect(response).to redirect_to(conference_broadcast_path(conference, broadcast))
        expect(broadcast.reload).to have_attributes(campaign: 'New campaign', description: 'New description', body: "Hello\n\nWorld")
      end
    end
  end
end
