# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessBroadcastDeliveryMailgunEventJob, type: :job do
  let(:broadcast) { FactoryBot.create(:broadcast, status: :sending) }
  let!(:delivery) { FactoryBot.create(:broadcast_delivery, broadcast:, status: :sent) }

  def event(id:, event:, timestamp:, delivery_id: delivery.id)
    {'id' => id, 'event' => event, 'timestamp' => timestamp, 'user-variables' => {'delivery_id' => delivery_id}}
  end

  it 'records the event and updates statuses' do
    described_class.perform_now(event(id: 'a', event: 'delivered', timestamp: 100))

    delivery.reload
    expect(delivery.status).to eq('delivered')
    expect(delivery.mailgun_events.map { it['id'] }).to eq(%w(a))
    expect(broadcast.reload.status).to eq('sent')
  end

  it 'reads a delivery_id sent as a string' do
    described_class.perform_now(event(id: 'a', event: 'opened', timestamp: 100, delivery_id: delivery.id.to_s))

    expect(delivery.reload.status).to eq('opened')
  end

  it 'raises without a delivery_id' do
    expect {
      described_class.perform_now({'id' => 'a', 'event' => 'delivered', 'timestamp' => 100})
    }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'discards an event it cannot read, reporting it' do
    allow(Sentry).to receive(:capture_exception)

    expect {
      described_class.perform_now({'id' => 'a', 'event' => 'delivered', 'user-variables' => {'delivery_id' => 'unknown'}})
    }.not_to raise_error
    expect(Sentry).to have_received(:capture_exception).with(instance_of(Google::Protobuf::ParseError))
    expect(delivery.reload.mailgun_events).to be_empty
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
