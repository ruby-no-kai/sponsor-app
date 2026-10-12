# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TitoApi do
  let(:endpoint) { 'https://tito.example.invalid/v3' }
  let(:api) { described_class.new(token: 'secret', endpoint:) }

  describe '#initialize' do
    it 'raises when the token is blank' do
      expect { described_class.new(token: '') }.to raise_error(ArgumentError, 'token is blank')
    end

    it 'raises when the token is nil' do
      expect { described_class.new(token: nil) }.to raise_error(ArgumentError, 'token is blank')
    end

    it 'defaults to the Tito v3 endpoint' do
      expect(described_class.new(token: 'secret').endpoint).to eq(described_class::ENDPOINT)
    end
  end

  describe 'requests' do
    it 'refuses an endpoint that is not an HTTP(S) URL' do
      api = described_class.new(token: 'secret', endpoint: 'ftp://tito.example.invalid/v3')
      expect { api.list_releases('rubykaigi/2025') }.to raise_error(ArgumentError, /not an HTTP\(S\) URL/)
    end

    it 'authenticates with the Tito token scheme and parses JSON with symbol keys' do
      stub = stub_request(:get, "#{endpoint}/rubykaigi/2025/registrations/reg_1")
        .with(headers: {'Authorization' => 'Token token=secret', 'Accept' => 'application/json'}, query: {'expand' => 'tickets'})
        .to_return(status: 200, headers: {'Content-Type' => 'application/json; charset=utf-8'}, body: '{"registration":{"id":1}}')

      expect(api.get_registration('rubykaigi/2025', 'reg_1', 'expand' => 'tickets')).to eq(registration: {id: 1})
      expect(stub).to have_been_requested
    end

    it 'sends array query values' do
      stub = stub_request(:get, "#{endpoint}/rubykaigi/2025/registrations")
        .with(query: hash_including('version' => '3.1', 'expand' => ['tickets']))
        .to_return(status: 200, headers: {'Content-Type' => 'application/json'}, body: '{"registrations":[]}')

      expect(api.list_registrations('rubykaigi/2025', 'expand' => %w[tickets])).to eq(registrations: [])
      expect(stub).to have_been_requested
    end

    it 'encodes the body as JSON' do
      stub = stub_request(:post, "#{endpoint}/rubykaigi/2025/discount_codes")
        .with(
          headers: {'Content-Type' => %r{\Aapplication/json}},
          body: {discount_code: {code: 'X', type: 'PercentOffDiscountCode', value: '100.0'}}.to_json,
        )
        .to_return(status: 201, headers: {'Content-Type' => 'application/json'}, body: '{"discount_code":{"id":"d1"}}')

      expect(api.create_discount_code('rubykaigi/2025', code: 'X', type: 'PercentOffDiscountCode', value: '100.0')).to eq(discount_code: {id: 'd1'})
      expect(stub).to have_been_requested
    end

    it 'returns an empty hash for an empty body' do
      stub_request(:post, "#{endpoint}/rubykaigi/2025/registrations/reg_1/cancellation").to_return(status: 204)

      expect(api.cancel_registration('rubykaigi/2025', 'reg_1')).to eq({})
    end

    it 'raises HTTPError with the status on 404' do
      stub_request(:get, "#{endpoint}/rubykaigi/2025/tickets/missing").to_return(status: 404, body: '{}')

      expect { api.get_ticket('rubykaigi/2025', 'missing') }.to raise_error(HTTPX::HTTPError) { |e| expect(e.status).to eq(404) }
    end

    it 'raises HTTPError on other error statuses' do
      stub_request(:get, "#{endpoint}/rubykaigi/2025/releases").to_return(status: 500, body: '{}')

      expect { api.list_releases('rubykaigi/2025') }.to raise_error(HTTPX::HTTPError) { |e| expect(e.status).to eq(500) }
    end
  end
end
