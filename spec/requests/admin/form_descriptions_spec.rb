# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin FormDescriptions", type: :request do
  let(:conference) { FactoryBot.create(:conference) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "GET show" do
    let(:form_description) do
      FactoryBot.create(:form_description, conference:, locale: 'en').tap do |fd|
        fd.update!(fallback_options: [{'value' => 'opt1', 'name' => 'Option 1', 'conditions' => [{'plans' => ['Ruby']}]}])
      end
    end

    it "renders fallback_options as JSON" do
      get conference_form_description_path(conference, form_description)
      expect(response).to have_http_status(:ok)

      json = Nokogiri::HTML(response.body).css('pre').map(&:text).join
      expect(JSON.parse(json)).to eq([{'value' => 'opt1', 'name' => 'Option 1', 'conditions' => [{'plans' => ['Ruby']}]}])
    end
  end
end
