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
  end
end
