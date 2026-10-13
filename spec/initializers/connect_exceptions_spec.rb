# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConnectExceptions do
  let(:app) { described_class.new(->(_env) { [418, {}, ['wrapped']] }) }

  def env_for(exception, **headers)
    Rack::MockRequest.env_for('/rubykaigi.sponsor_app.AdminService/GetViewer', method: 'POST', **headers).merge(
      'action_dispatch.exception' => exception,
      'action_dispatch.request_id' => 'request-1',
      'action_dispatch.original_request_method' => 'POST',
    )
  end

  def details_of(body)
    JSON.parse(body.join).fetch('details').to_h do |detail|
      klass = Google::Protobuf::DescriptorPool.generated_pool.lookup(detail.fetch('type')).msgclass
      [klass, klass.decode(Base64.decode64(detail.fetch('value')))]
    end
  end

  it 'answers an escaped problem with its own status and document' do
    status, headers, body = app.call(env_for(Errors::NotFound.new(detail: 'gone'), 'HTTP_CONNECT_PROTOCOL_VERSION' => '1'))

    expect([status, headers['content-type']]).to eq([404, 'application/json'])
    expect(JSON.parse(body.join)).to include('code' => 'not_found', 'message' => 'gone')
    details = details_of(body)
    expect(details.fetch(Protobufable::ProblemDetails)).to have_attributes(
      type: 'https://sponsorships.rubykaigi.org/problems/not-found', status: 404, detail: 'gone',
    )
    expect(details.fetch(Google::Rpc::RequestInfo).request_id).to eq('request-1')
  end

  it 'answers any other exception with the status text only' do
    status, _headers, body = app.call(env_for(ActiveRecord::RecordNotFound.new('Couldn\'t find Conference with secret'), 'HTTP_CONNECT_PROTOCOL_VERSION' => '1'))

    expect(status).to eq(404)
    expect(JSON.parse(body.join)).to include('code' => 'not_found', 'message' => 'Not Found')
    expect(details_of(body).keys).to eq([Google::Rpc::RequestInfo])
  end

  it 'passes a request that is not a Connect call to the wrapped app' do
    expect(app.call(env_for(RuntimeError.new))).to eq([418, {}, ['wrapped']])
  end
end
