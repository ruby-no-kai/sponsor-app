# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Conferences", type: :request do
  let(:conference) { FactoryBot.create(:conference) }
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
  end
end
