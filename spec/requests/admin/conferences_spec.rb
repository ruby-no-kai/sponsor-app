# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Conferences", type: :request do
  let(:conference) { FactoryBot.create(:conference, github_repo: 'ruby-no-kai/rubykaigi.org@master:data', allow_restricted_access: true) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "DELETE destroy" do
    it "destroys the conference" do
      delete conference_path(conference)
      expect(response).to redirect_to(conferences_url)
      expect(Conference.exists?(conference.id)).to be(false)
    end

    context "with restricted staff authorized for the conference" do
      let(:staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi.org']) }

      it "is forbidden" do
        delete conference_path(conference)
        expect(response).to have_http_status(:forbidden)
        expect(Conference.exists?(conference.id)).to be(true)
      end
    end
  end
end
