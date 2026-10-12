# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Connect errors from exceptions', type: :request do
  let(:rpc) { connect_method('AdminService', 'GetViewer') }
  let(:request_message) { Rk::SponsorApp::AdminServiceGetViewerRequest.new }

  before { sign_in_staff(FactoryBot.create(:staff)) }

  it "answers an exception Rails classifies with its code and the status text, not the exception's message" do
    allow(Api::StaffResource).to receive(:new).and_raise(ActiveRecord::RecordNotFound, "Couldn't find Staff with secret")

    error = connect_call(rpc, request_message)

    expect(error).to have_attributes(status: 404, code: 'not_found', message: 'Not Found')
    expect(error.detail(Google::Rpc::RequestInfo)).to be_present
  end

  it 'reports a server-side problem to Sentry' do
    problem = Errors::Internal.new(detail: 'The ledger is unreachable.')
    allow(Api::StaffResource).to receive(:new).and_raise(problem)
    allow(Sentry).to receive(:capture_exception)

    error = connect_call(rpc, request_message)

    expect(error).to have_attributes(status: 500, code: 'internal', message: 'The ledger is unreachable.')
    expect(error.detail(Protobufable::ProblemDetails).type).to eq('https://sponsorships.rubykaigi.org/problems/internal')
    expect(Sentry).to have_received(:capture_exception).with(problem)
  end

  it 'leaves a client-side problem unreported' do
    allow(Api::StaffResource).to receive(:new).and_raise(Errors::Conflict.new(detail: 'Edited elsewhere.'))
    allow(Sentry).to receive(:capture_exception)

    expect(connect_call(rpc, request_message)).to have_attributes(code: 'aborted')
    expect(Sentry).not_to have_received(:capture_exception)
  end

  context 'when the exception escapes the controller' do
    around do |example|
      env_config = Rails.application.env_config
      original = env_config.slice('action_dispatch.show_exceptions', 'action_dispatch.show_detailed_exceptions')
      env_config['action_dispatch.show_exceptions'] = :all
      env_config['action_dispatch.show_detailed_exceptions'] = false
      example.run
    ensure
      env_config.merge!(original)
    end

    before { allow(Api::StaffResource).to receive(:new).and_raise(RuntimeError, 'internals the caller must not see') }

    it 'answers an unhandled exception as internal, with the request ID' do
      error = connect_call(rpc, request_message)

      expect(error).to have_attributes(status: 500, code: 'internal', message: 'Internal Server Error')
      expect(error.detail(Google::Rpc::RequestInfo).request_id).to eq(response.headers['X-Request-Id'])
    end

    it 'recognises a GET as a Connect call' do
      expect(connect_call(rpc, request_message, via: :get)).to have_attributes(code: 'internal')
    end

    it 'keeps the static error page for other requests' do
      get '/admin/conferences/nonexistent'

      expect(response).to have_http_status(:not_found)
      expect(response.media_type).to eq('text/html')
    end
  end
end
