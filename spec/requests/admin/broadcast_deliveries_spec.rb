# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Broadcast Deliveries", type: :request do
  filter_class = Rk::SponsorApp::Internal::BroadcastRecipientFilter

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
        expect(CreateBroadcastDeliveriesJob).to have_received(:perform_later).with(
          broadcast,
          [filter_class.new(raw: filter_class::Raw.new(emails: ['someone@example.com']))],
        )
      end

      it "queues the plan and status of current sponsors" do
        post conference_broadcast_deliveries_path(conference, broadcast), params: {
          recipient_filter: {kind: 'all', locale: 'ja', exhibitors: '1', plan_id: '12', status: 'active'},
        }

        expect(CreateBroadcastDeliveriesJob).to have_received(:perform_later).with(
          broadcast,
          [
            filter_class.new(
              current_sponsors: filter_class::CurrentSponsors.new(
                locale: 'ja',
                exhibitors_only: true,
                plan_id: 12,
                status: :SPONSORSHIP_STATUS_ACTIVE,
              ),
            ),
          ],
        )
      end

      it "queues every field of past sponsors" do
        post conference_broadcast_deliveries_path(conference, broadcast), params: {
          recipient_filter: {kind: 'past_sponsors', id: '7', locale: 'en', exclude_current_sponsors: '1', status: 'pending'},
        }

        expect(CreateBroadcastDeliveriesJob).to have_received(:perform_later).with(
          broadcast,
          [
            filter_class.new(
              past_sponsors: filter_class::PastSponsors.new(
                conference_id: 7,
                locale: 'en',
                exclude_current_sponsors: true,
                status: :SPONSORSHIP_STATUS_PENDING,
              ),
            ),
          ],
        )
      end

      it "refuses an unknown status and leaves the broadcast ready" do
        post conference_broadcast_deliveries_path(conference, broadcast), params: {
          recipient_filter: {kind: 'all', status: 'bogus'},
        }

        expect(response).to have_http_status(:bad_request)
        expect(broadcast.reload).to be_ready
        expect(CreateBroadcastDeliveriesJob).not_to have_received(:perform_later)
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
