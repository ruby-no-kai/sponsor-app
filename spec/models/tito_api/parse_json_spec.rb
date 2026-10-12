# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TitoApi::ParseJson do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:conn) do
    Faraday.new(url: 'https://tito.invalid/v3') do |builder|
      builder.use described_class, content_type: /\bjson$/, parser_options: {symbolize_names: true}
      builder.use FaradayMiddleware::EncodeJson
      builder.adapter :test, stubs
    end
  end

  it 'parses JSON responses with symbolized keys' do
    stubs.post('/v3/rubykaigi/2026/discount_codes') do |env|
      [200, {'Content-Type' => 'application/json'}, %({"echo":#{env.body}})]
    end

    expect(conn.post('rubykaigi/2026/discount_codes', {code: 'x'}).body).to eq(echo: {code: 'x'})
  end

  it 'leaves an empty body unparsed' do
    stubs.delete('/v3/rubykaigi/2026/registrations/r') { [200, {'Content-Type' => 'application/json'}, ' '] }

    expect(conn.delete('rubykaigi/2026/registrations/r').body).to be_nil
  end

  it 'is the parser TitoApi connects with' do
    expect(TitoApi.new(token: 'token').faraday.builder.handlers).to include(described_class)
  end
end
