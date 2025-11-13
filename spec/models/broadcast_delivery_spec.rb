require 'rails_helper'

RSpec.describe BroadcastDelivery, type: :model do
  let(:broadcast) { FactoryBot.build_stubbed(:broadcast) }

  describe '#mailgun_events' do
    it 'returns empty array by default' do
      delivery = FactoryBot.build_stubbed(:broadcast_delivery, broadcast:)
      expect(delivery.mailgun_events).to eq([])
    end

    it 'returns stored events' do
      delivery = FactoryBot.build_stubbed(:broadcast_delivery, broadcast:)
      delivery.meta = {'mailgun_events' => [{'event' => 'delivered', 'timestamp' => 123}]}
      expect(delivery.mailgun_events).to eq([{'event' => 'delivered', 'timestamp' => 123}])
    end
  end

  describe '#add_mailgun_event' do
    it 'adds event to mailgun_events' do
      delivery = FactoryBot.build_stubbed(:broadcast_delivery, broadcast:)
      delivery.add_mailgun_event({'event' => 'delivered', 'timestamp' => 123})
      expect(delivery.mailgun_events).to include({'event' => 'delivered', 'timestamp' => 123})
    end

    it 'sorts events by timestamp' do
      delivery = FactoryBot.build_stubbed(:broadcast_delivery, broadcast:)
      delivery.add_mailgun_event({'event' => 'opened', 'timestamp' => 200})
      delivery.add_mailgun_event({'event' => 'delivered', 'timestamp' => 100})
      expect(delivery.mailgun_events.first['timestamp']).to eq(100)
    end
  end

  describe '#recipient_ccs' do
    it 'parses comma-separated emails' do
      delivery = FactoryBot.build_stubbed(:broadcast_delivery, :with_cc, broadcast:)
      expect(delivery.recipient_ccs).to eq(['cc1@example.com', 'cc2@example.com'])
    end

    it 'returns empty array when nil' do
      delivery = FactoryBot.build_stubbed(:broadcast_delivery, broadcast:)
      expect(delivery.recipient_ccs).to eq([])
    end
  end
end
