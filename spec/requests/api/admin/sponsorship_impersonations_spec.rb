# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService sponsorship impersonation', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }
  let(:rpc) { connect_method('AdminService', 'ImpersonateSponsorship') }

  def request_for(sponsorship)
    Rk::SponsorApp::AdminServiceImpersonateSponsorshipRequest.new(conference_slug: conference.slug, sponsorship_id: sponsorship.id)
  end

  context 'when impersonation is enabled' do
    before do
      allow(Rails.configuration.x.dev).to receive(:sponsor_impersonation).and_return(true)
    end

    it "returns the path claiming a one-minute session as the sponsorship's contact" do
      sign_in_staff(staff)

      claim_path = connect_call(rpc, request_for(sponsorship)).claim_path

      token = SessionToken.order(:id).last
      expect(token).to have_attributes(email: sponsorship.contact.email, staff: nil, sponsorship: nil)
      expect(token.expires_at).to be_within(5.seconds).of(1.minute.from_now)
      expect(claim_path).to eq(claim_user_session_path(token))
    end

    it 'tells GetSponsorship that it is available' do
      sign_in_staff(staff)
      get_request = Rk::SponsorApp::AdminServiceGetSponsorshipRequest.new(conference_slug: conference.slug, sponsorship_id: sponsorship.id)

      expect(connect_call(connect_method('AdminService', 'GetSponsorship'), get_request).impersonation_enabled).to be(true)
    end

    it 'answers not_found for a sponsorship of another conference' do
      other_conference = FactoryBot.create(:conference, :full)
      elsewhere = FactoryBot.create(:sponsorship, conference: other_conference, plan: other_conference.plans.first)
      sign_in_staff(staff)

      expect { expect(connect_call(rpc, request_for(elsewhere))).to have_attributes(code: 'not_found') }.not_to change(SessionToken, :count)
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect { expect(connect_call(rpc, request_for(sponsorship))).to have_attributes(code: 'permission_denied') }
        .not_to change(SessionToken, :count)
    end
  end

  it 'answers not_found unless impersonation is enabled' do
    sign_in_staff(staff)

    expect do
      error = connect_call(rpc, request_for(sponsorship))
      expect(error).to have_attributes(status: 404, code: 'not_found')
      expect(problem_type_of(error)).to eq('not-found')
    end.not_to change(SessionToken, :count)
  end

  it 'answers unauthenticated without a staff session' do
    allow(Rails.configuration.x.dev).to receive(:sponsor_impersonation).and_return(true)

    expect { expect(connect_call(rpc, request_for(sponsorship))).to have_attributes(status: 401, code: 'unauthenticated') }
      .not_to change(SessionToken, :count)
  end
end
