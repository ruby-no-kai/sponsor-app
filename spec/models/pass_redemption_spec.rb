# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PassRedemption do
  let(:ticket) do
    PassRedemption::Ticket.new(
      id: 1, reference: 'T-1',
      discount_code: 'CODE', release: nil, release_id: '10',
      email: 'ticket@example.invalid',
      state: 'complete',
      void: false, assigned: true,
    )
  end

  let(:registration) do
    PassRedemption::Registration.new(
      id: 2, reference: 'R-1',
      discount_code: 'CODE', source: 'src',
      email: 'reg@example.invalid',
      state: 'complete',
      free: true, paid: false, cancelled: false, refunded: false, partially_refunded: false,
      tickets: [ticket],
    )
  end

  describe 'JSON serialization' do
    it 'serializes with encoder options as render json: passes them' do
      json = JSON.parse({registrations: [registration]}.to_json(status: :ok))

      expect(json.dig('registrations', 0)).to include(
        'reference' => 'R-1',
        'retractable' => true,
        'tickets' => [include('reference' => 'T-1', 'release_id' => '10')],
      )
    end
  end
end
