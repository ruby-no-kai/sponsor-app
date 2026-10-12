# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Dashboard", type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    allow(SlackWebhookJob).to receive(:perform_later)
    allow(ErrorTownJob).to receive(:perform_later)
    get claim_user_session_path(session_token.handle)
  end

  context "with unrestricted staff" do
    it "notifies slack on slacktown" do
      get slacktown_path
      expect(response).to have_http_status(:ok)
      expect(SlackWebhookJob).to have_received(:perform_later)
    end

    it "sends a test mail on mailtown" do
      expect { get mailtown_path(to: 'staff@example.invalid') }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(response).to have_http_status(:ok)
    end

    it "raises on errortown" do
      expect { get errortown_path }.to raise_error(Admin::DashboardController::Boom)
      expect(ErrorTownJob).to have_received(:perform_later)
    end
  end

  context "with restricted staff" do
    let(:staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi.org']) }

    it "forbids slacktown" do
      get slacktown_path
      expect(response).to have_http_status(:forbidden)
      expect(SlackWebhookJob).not_to have_received(:perform_later)
    end

    it "forbids mailtown" do
      expect { get mailtown_path(to: 'staff@example.invalid') }.not_to change { ActionMailer::Base.deliveries.size }
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids errortown" do
      get errortown_path
      expect(response).to have_http_status(:forbidden)
      expect(ErrorTownJob).not_to have_received(:perform_later)
    end
  end
end
