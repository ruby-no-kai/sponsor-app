# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Connect forgery protection', type: :request do
  let(:rpc) { connect_method('AdminService', 'GetViewer') }
  let(:request_message) { Rk::SponsorApp::AdminServiceGetViewerRequest.new }
  let(:staff) { FactoryBot.create(:staff) }

  before { sign_in_staff(staff) }

  it 'rejects a POST without Connect-Protocol-Version' do
    post rpc.path, params: '{}', headers: {'Content-Type' => 'application/json'}

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body).to include('code' => 'invalid_argument')
  end

  it 'rejects a POST with another Connect-Protocol-Version' do
    error = connect_call(rpc, request_message, headers: {'Connect-Protocol-Version' => '2'})

    expect(error).to have_attributes(code: 'invalid_argument')
  end

  it 'rejects a POST without Connect-Protocol-Version before authenticating it' do
    reset!

    post rpc.path, params: '{}', headers: {'Content-Type' => 'application/json'}

    expect(response.parsed_body).to include('code' => 'invalid_argument')
  end

  ['same-origin', 'none'].each do |site|
    it "serves Sec-Fetch-Site: #{site}" do
      expect(connect_call(rpc, request_message, headers: {'Sec-Fetch-Site' => site}).staff.login).to eq(staff.login)
    end
  end

  ['same-site', 'cross-site'].each do |site|
    it "rejects Sec-Fetch-Site: #{site}" do
      error = connect_call(rpc, request_message, headers: {'Sec-Fetch-Site' => site})

      expect(error).to have_attributes(status: 403, code: 'permission_denied')
    end

    it "rejects a GET with Sec-Fetch-Site: #{site}" do
      expect(connect_call(rpc, request_message, via: :get, headers: {'Sec-Fetch-Site' => site}))
        .to have_attributes(code: 'permission_denied')
    end
  end

  it 'serves an Origin matching this site' do
    expect(connect_call(rpc, request_message, headers: {'Origin' => 'http://www.example.com'}).staff.login).to eq(staff.login)
  end

  ['http://evil.invalid', 'https://www.example.com', 'null'].each do |origin|
    it "rejects Origin: #{origin}" do
      expect(connect_call(rpc, request_message, headers: {'Origin' => origin})).to have_attributes(code: 'permission_denied')
    end
  end
end
