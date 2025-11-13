require 'rails_helper'

RSpec.describe Broadcast, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:staff) { FactoryBot.create(:staff) }

  describe '#update_status' do
    let(:broadcast) { FactoryBot.create(:broadcast, staff:, conference:, status: :ready) }

    it 'updates status to sent when all deliveries are sent' do
      FactoryBot.create(:broadcast_delivery, broadcast:, status: :sent)
      broadcast.update_status
      expect(broadcast.status).to eq('sent')
    end

    it 'updates status to sending when some deliveries are pending' do
      FactoryBot.create(:broadcast_delivery, broadcast:, status: :sent)
      FactoryBot.create(:broadcast_delivery, broadcast:, status: :pending)
      broadcast.update_status
      expect(broadcast.status).to eq('sending')
    end
  end
end
