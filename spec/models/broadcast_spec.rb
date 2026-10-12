# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Broadcast, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:staff) { FactoryBot.create(:staff) }

  describe 'delivered content immutability' do
    let(:broadcast) { FactoryBot.create(:broadcast, staff:, conference:, status:) }

    context 'when sent' do
      let(:status) { :sent }

      it 'forbids changing title' do
        broadcast.title = 'New title'
        expect(broadcast).not_to be_valid
        expect(broadcast.errors[:title]).to be_present
      end

      it 'forbids changing body' do
        broadcast.body = 'New body'
        expect(broadcast).not_to be_valid
        expect(broadcast.errors[:body]).to be_present
      end

      it 'allows changing campaign and description' do
        broadcast.assign_attributes(campaign: 'New campaign', description: 'New description')
        expect(broadcast).to be_valid
      end
    end

    context 'when not sent' do
      let(:status) { :ready }

      it 'allows changing title and body' do
        broadcast.assign_attributes(title: 'New title', body: 'New body')
        expect(broadcast).to be_valid
      end
    end
  end

  describe '#update_status' do
    let(:broadcast) { FactoryBot.create(:broadcast, staff:, conference:, status: :pending) }

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

    %i(created preparing modifying ready).each do |status|
      it "keeps #{status} broadcast as is before dispatch" do
        broadcast.update!(status:)
        FactoryBot.create(:broadcast_delivery, broadcast:, status: :ready)
        broadcast.update_status
        expect(broadcast.status).to eq(status.to_s)
      end
    end
  end
end
