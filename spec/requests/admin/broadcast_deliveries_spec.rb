# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Broadcast Deliveries", type: :request do
  let(:conference) { FactoryBot.create(:conference) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }
  let(:broadcast) { FactoryBot.create(:broadcast, conference:, status:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "POST create" do
    let(:recipient_filter) { {kind: 'raw', emails: 'someone@example.com'} }

    before { allow(CreateBroadcastDeliveriesJob).to receive(:perform_later) }

    context "when the broadcast is ready" do
      let(:status) { :ready }

      it "queues additional deliveries" do
        post conference_broadcast_deliveries_path(conference, broadcast), params: {recipient_filter:}

        expect(response).to redirect_to(conference_broadcast_path(conference, broadcast))
        expect(broadcast.reload).to be_modifying
        expect(CreateBroadcastDeliveriesJob).to have_received(:perform_later).with(broadcast, [instance_of(ActionController::Parameters)])
      end
    end

    context "when the broadcast is sent" do
      let(:status) { :sent }

      it "refuses to modify it" do
        post conference_broadcast_deliveries_path(conference, broadcast), params: {recipient_filter:}

        expect(response).to redirect_to(conference_broadcast_path(conference, broadcast))
        expect(flash[:error]).to eq('Unable to modify')
        expect(CreateBroadcastDeliveriesJob).not_to have_received(:perform_later)
      end
    end
  end

  describe "DELETE destroy" do
    let(:status) { :ready }

    it "removes a ready delivery" do
      delivery = FactoryBot.create(:broadcast_delivery, broadcast:, status: :ready)

      expect do
        delete conference_broadcast_delivery_path(conference, broadcast, delivery)
      end.to change(BroadcastDelivery, :count).by(-1)
      expect(response).to redirect_to(conference_broadcast_path(conference, broadcast))
    end

    it "forbids removing a sent delivery" do
      delivery = FactoryBot.create(:broadcast_delivery, :sent, broadcast:)

      expect do
        delete conference_broadcast_delivery_path(conference, broadcast, delivery)
      end.not_to change(BroadcastDelivery, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
