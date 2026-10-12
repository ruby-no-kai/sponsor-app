# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DispatchBroadcastDeliveryJob, type: :job do
  let(:broadcast) { FactoryBot.create(:broadcast, status: :pending) }
  let(:delivery) { FactoryBot.create(:broadcast_delivery, broadcast:, status: :pending, recipient: 'to@example.com') }

  it 'sends the announcement and marks the delivery and broadcast sent' do
    expect { described_class.perform_now(delivery) }.to change(ActionMailer::Base.deliveries, :size).by(1)

    expect(ActionMailer::Base.deliveries.last.to).to eq(['to@example.com'])
    expect(delivery.reload).to be_sent
    expect(broadcast.reload).to be_sent
  end

  it 'skips a delivery that was already sent' do
    delivery.update!(status: :sent)

    expect { described_class.perform_now(delivery) }.not_to change(ActionMailer::Base.deliveries, :size)
  end
end
