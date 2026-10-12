# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessBroadcastDeliveryMailgunEventJob, type: :job do
  let(:broadcast) { FactoryBot.create(:broadcast, status: :sending) }
  let!(:delivery) { FactoryBot.create(:broadcast_delivery, broadcast:, status: :sent) }

  def event(id:, event:, timestamp:)
    {'id' => id, 'event' => event, 'timestamp' => timestamp, 'user-variables' => {'delivery_id' => delivery.id}}
  end

  it 'records the event and updates statuses' do
    described_class.perform_now(event(id: 'a', event: 'delivered', timestamp: 100))

    delivery.reload
    expect(delivery.status).to eq('delivered')
    expect(delivery.mailgun_events.map { it['id'] }).to eq(%w(a))
    expect(broadcast.reload.status).to eq('sent')
  end

  context 'with an event older than the latest recorded one' do
    before do
      described_class.perform_now(event(id: 'b', event: 'opened', timestamp: 200))
    end

    it 'records the event without changing status' do
      described_class.perform_now(event(id: 'a', event: 'delivered', timestamp: 100))

      delivery.reload
      expect(delivery.status).to eq('opened')
      expect(delivery.mailgun_events.map { it['id'] }).to eq(%w(a b))
    end
  end
end
