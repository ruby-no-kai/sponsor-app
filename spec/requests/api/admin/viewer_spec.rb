# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService viewer', type: :request do
  let(:staff) { FactoryBot.create(:staff, avatar_url: 'https://avatars.invalid/orgz.png') }

  describe 'GetViewer' do
    let(:rpc) { connect_method('AdminService', 'GetViewer') }
    let(:request_message) { Rk::SponsorApp::AdminServiceGetViewerRequest.new }

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'returns the signed-in staff member over POST JSON' do
        expect(connect_call(rpc, request_message).staff).to have_attributes(
          login: staff.login,
          name: staff.name,
          avatar_url: 'https://avatars.invalid/orgz.png',
          restricted: false,
        )
      end

      it 'answers a GET and a binary call alike' do
        expect(connect_call(rpc, request_message, via: :get).staff.login).to eq(staff.login)
        expect(connect_call(rpc, request_message, codec: :proto).staff.login).to eq(staff.login)
      end
    end

    it 'flags a restricted staff member and leaves out a missing avatar' do
      sign_in_staff(FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']))

      viewer = connect_call(rpc, request_message).staff

      expect(viewer.restricted).to be(true)
      expect(viewer.has_avatar_url?).to be(false)
    end

    it 'answers unauthenticated with the problem document and the request ID' do
      error = connect_call(rpc, request_message)

      expect(error).to have_attributes(status: 401, code: 'unauthenticated', message: 'Sign in to the staff area.')
      expect(error.detail(Protobufable::ProblemDetails)).to have_attributes(
        type: 'https://sponsorships.rubykaigi.org/problems/unauthenticated',
        title: 'Unauthenticated',
        status: 401,
      )
      expect(error.detail(Google::Rpc::RequestInfo).request_id).to eq(response.request.request_id)
      expect(error.detail(Google::Rpc::RequestInfo).request_id).to be_present
    end

    it 'localizes the problem title' do
      cookies['__Host-rk-sponsorapp2-hl'] = 'ja'

      error = connect_call(rpc, request_message)

      expect(error.detail(Protobufable::ProblemDetails).title).to eq('ログインが必要です')
    end
  end

  describe 'SignOut' do
    let(:rpc) { connect_method('AdminService', 'SignOut') }
    let(:get_viewer) { connect_method('AdminService', 'GetViewer') }

    it 'ends the staff session and keeps the sponsor session' do
      sponsorship = FactoryBot.create(:sponsorship)
      FactoryBot.create(:session_token, email: sponsorship.contact.email, staff:).then do |token|
        get claim_user_session_path(token.handle)
      end

      expect(connect_call(rpc, Rk::SponsorApp::AdminServiceSignOutRequest.new)).to eq(Rk::SponsorApp::AdminServiceSignOutResponse.new)
      expect(connect_call(get_viewer, Rk::SponsorApp::AdminServiceGetViewerRequest.new)).to have_attributes(code: 'unauthenticated')
      expect(session[:sponsorship_ids]).to eq([sponsorship.id])
    end

    it 'answers a binary call' do
      sign_in_staff(staff)

      expect(connect_call(rpc, Rk::SponsorApp::AdminServiceSignOutRequest.new, codec: :proto)).to eq(Rk::SponsorApp::AdminServiceSignOutResponse.new)
      expect(connect_call(get_viewer, Rk::SponsorApp::AdminServiceGetViewerRequest.new)).to have_attributes(code: 'unauthenticated')
    end

    it 'refuses GET, as it has side effects' do
      sign_in_staff(staff)

      error = connect_call(rpc, Rk::SponsorApp::AdminServiceSignOutRequest.new, via: :get)

      expect(error.status).to eq(405)
      expect(response.headers['Allow']).to eq('POST')
      expect(connect_call(get_viewer, Rk::SponsorApp::AdminServiceGetViewerRequest.new).staff.login).to eq(staff.login)
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, Rk::SponsorApp::AdminServiceSignOutRequest.new)).to have_attributes(code: 'unauthenticated')
    end
  end
end
