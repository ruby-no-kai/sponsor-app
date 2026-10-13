# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Connect RPC policies', type: :request do
  let(:get_viewer) { connect_method('AdminService', 'GetViewer') }
  let(:get_conference) { connect_method('AdminService', 'GetConference') }

  # Under eager loading, drawing the route resolves the controller, so only the stubbed probe is routed.
  def with_probe_routes(controller, &)
    with_routing do |routes|
      routes.draw do
        get '/session/claim/:handle' => 'sessions#claim', as: :claim_user_session
        connect_service 'rubykaigi.sponsor_app.AdminService' => controller
      end
      yield
    end
  end

  def stub_admin_probe(&body)
    stub_const('Api::Admin::PolicyProbeController', Class.new(Api::Admin::ApplicationController, &body))
  end

  # A sponsor controller borrowing GetConference for its request carrying conference_slug.
  def stub_sponsor_probe(&body)
    stub_const('Api::Sponsor::PolicyProbeController', Class.new(Api::Sponsor::ApplicationController) do
      connect_service 'rubykaigi.sponsor_app.AdminService'
      class_eval(&body)
    end)
  end

  def conference_request(slug) = Rk::SponsorApp::AdminServiceGetConferenceRequest.new(conference_slug: slug)

  describe ':unrestricted_staff' do
    before do
      stub_admin_probe do
        authorize :unrestricted_staff
        define_method(:get_viewer) { Rk::SponsorApp::AdminServiceGetViewerResponse.new }
      end
    end

    it 'serves unrestricted staff' do
      with_probe_routes('api/admin/policy_probe') do
        sign_in_staff(FactoryBot.create(:staff))

        expect(connect_call(get_viewer, Rk::SponsorApp::AdminServiceGetViewerRequest.new))
          .to eq(Rk::SponsorApp::AdminServiceGetViewerResponse.new)
      end
    end

    it 'answers permission_denied to restricted staff' do
      with_probe_routes('api/admin/policy_probe') do
        sign_in_staff(FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']))

        expect(connect_call(get_viewer, Rk::SponsorApp::AdminServiceGetViewerRequest.new))
          .to have_attributes(code: 'permission_denied')
      end
    end
  end

  describe ':sponsorship' do
    let(:sponsorship) { FactoryBot.create(:sponsorship) }

    before do
      stub_sponsor_probe do
        authorize :sponsorship
        define_method(:get_conference) do
          Rk::SponsorApp::AdminServiceGetConferenceResponse.new(
            conference: Rk::SponsorApp::AdminConference.new(conference: Rk::SponsorApp::Conference.new(name: current_sponsorship.name)),
          )
        end
      end
    end

    it "serves the contact's sponsorship in the conference the request names" do
      with_probe_routes('api/sponsor/policy_probe') do
        sign_in_sponsor(sponsorship.contact.email)

        expect(connect_call(get_conference, conference_request(sponsorship.conference.slug)).conference.conference.name)
          .to eq(sponsorship.name)
      end
    end

    it 'reports errors as the signed-in contact' do
      with_probe_routes('api/sponsor/policy_probe') do
        sign_in_sponsor(sponsorship.contact.email)
        allow(Sentry).to receive(:set_user)

        connect_call(get_conference, conference_request(sponsorship.conference.slug))

        expect(Sentry).to have_received(:set_user).with(id: sponsorship.id.to_s, email: sponsorship.contact.email)
      end
    end

    it 'answers not_found for a conference the contact does not sponsor' do
      other = FactoryBot.create(:conference)

      with_probe_routes('api/sponsor/policy_probe') do
        sign_in_sponsor(sponsorship.contact.email)

        expect(connect_call(get_conference, conference_request(other.slug))).to have_attributes(code: 'not_found')
      end
    end

    it 'answers not_found for a withdrawn sponsorship' do
      sponsorship.update!(withdrawn_at: Time.zone.now)

      with_probe_routes('api/sponsor/policy_probe') do
        sign_in_sponsor(sponsorship.contact.email)

        expect(connect_call(get_conference, conference_request(sponsorship.conference.slug))).to have_attributes(code: 'not_found')
      end
    end

    it 'answers unauthenticated without a sponsor session, before judging the request' do
      with_probe_routes('api/sponsor/policy_probe') do
        expect(connect_call(get_conference, conference_request('Not A Slug'))).to have_attributes(code: 'unauthenticated')
      end
    end
  end

  it 'raises for an RPC served without a policy' do
    stub_admin_probe do
      define_method(:get_viewer) { Rk::SponsorApp::AdminServiceGetViewerResponse.new }
    end

    with_probe_routes('api/admin/policy_probe') do
      sign_in_staff(FactoryBot.create(:staff))

      expect { connect_call(get_viewer, Rk::SponsorApp::AdminServiceGetViewerRequest.new) }
        .to raise_error(Api::ApplicationController::UndeclaredPolicy)
    end
  end

  it 'refuses a policy the service does not define' do
    expect { stub_admin_probe { authorize :public } }.to raise_error(ArgumentError, /no policy :public/)
  end

  it 'refuses a policy declared for a method that is not an RPC' do
    expect do
      stub_admin_probe do
        authorize :any_staff
        define_method(:helper) { nil }
      end
    end.to raise_error(ArgumentError, /not an RPC/)
  end

  it 'answers unimplemented for a routed RPC the controller does not define, after authentication' do
    stub_admin_probe { nil }

    with_probe_routes('api/admin/policy_probe') do
      expect(connect_call(get_viewer, Rk::SponsorApp::AdminServiceGetViewerRequest.new)).to have_attributes(code: 'unauthenticated')

      sign_in_staff(FactoryBot.create(:staff))
      expect(connect_call(get_viewer, Rk::SponsorApp::AdminServiceGetViewerRequest.new)).to have_attributes(code: 'unimplemented')
    end
  end
end
