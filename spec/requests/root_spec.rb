require 'rails_helper'

RSpec.describe "Root page", type: :request do
  let(:session_cookie_name) { '__Host-rk-sponsorapp2-hl' }

  describe "GET /" do
    context "when unauthenticated with a single open conference" do
      let!(:conference) do
        FactoryBot.create(:conference, application_opens_at: 1.day.ago, hidden: false)
      end

      it "renders the root page with sponsorship and login links" do
        get '/'
        expect(response).to have_http_status(200)
        expect(response.body).to include(new_user_conference_sponsorship_path(conference))
        expect(response.body).to include(new_user_session_path)
      end

      it "does not include CSRF meta tag" do
        get '/'
        expect(response.body).not_to include('csrf-token')
      end

      it "does not set a session cookie" do
        get '/'
        set_cookie_header = response.headers['Set-Cookie']
        expect(set_cookie_header.to_s).not_to include('rk-sponsorapp2-sess')
      end

      it "sets Cache-Control with s-maxage=3600" do
        get '/'
        expect(response.headers['Cache-Control']).to include('s-maxage=3600')
      end
    end

    context "when unauthenticated with multiple open conferences" do
      let!(:conference1) do
        FactoryBot.create(:conference, application_opens_at: 1.day.ago, hidden: false)
      end
      let!(:conference2) do
        FactoryBot.create(:conference, application_opens_at: 1.day.ago, hidden: false)
      end

      it "renders links for each conference" do
        get '/'
        expect(response).to have_http_status(200)
        expect(response.body).to include(new_user_conference_sponsorship_path(conference1))
        expect(response.body).to include(new_user_conference_sponsorship_path(conference2))
        expect(response.body).to include(new_user_session_path)
      end
    end

    context "when unauthenticated with no open conferences" do
      it "renders a message with org name and login link" do
        get '/'
        expect(response).to have_http_status(200)
        expect(response.body).to include(Rails.application.config.x.org_name)
        expect(response.body).to include(new_user_session_path)
      end
    end

    context "when logged in with a sponsorship session" do
      let!(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago, hidden: false) }
      let!(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }
      let!(:session_token) { FactoryBot.create(:session_token, email: sponsorship.contact.email) }

      it "redirects to /conferences" do
        get claim_user_session_path(session_token.handle)
        get '/'
        expect(response).to redirect_to(user_conferences_path)
      end
    end

    context "when logged in as staff only" do
      let!(:staff) { FactoryBot.create(:staff) }
      let!(:session_token) { FactoryBot.create(:session_token, staff:) }

      before do
        get claim_user_session_path(session_token.handle)
      end

      it "renders the root page" do
        get '/'
        expect(response).to have_http_status(200)
        expect(response.body).to include(new_user_session_path)
      end

      it "does not set Cache-Control s-maxage" do
        get '/'
        expect(response.headers['Cache-Control']).not_to include('s-maxage')
      end
    end

    context "locale" do
      it "renders in Japanese when hl=ja" do
        get '/', params: { hl: 'ja' }
        expect(response).to have_http_status(200)
        expect(response.body).to include('ログイン')
      end

      it "reads locale from cookie" do
        cookies[session_cookie_name] = 'ja'
        get '/'
        expect(response).to have_http_status(200)
        expect(response.body).to include('ログイン')
      end
    end
  end
end
