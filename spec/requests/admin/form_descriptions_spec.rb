# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Form Descriptions", type: :request do
  let(:conference) { FactoryBot.create(:conference) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "GET new" do
    it "renders the form" do
      get new_conference_form_description_path(conference)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST create" do
    it "creates a form description for the conference" do
      expect do
        post conference_form_descriptions_path(conference), params: {form_description: {locale: 'ja', head: '- Head'}}
      end.to change(conference.form_descriptions, :count).by(1)

      form_description = conference.form_descriptions.last
      expect(response).to redirect_to(conference_form_description_path(conference, form_description))
    end
  end

  describe "existing form description" do
    let!(:form_description) { FactoryBot.create(:form_description, conference:, locale: 'en') }

    it "shows the form description" do
      get conference_form_description_path(conference, form_description)
      expect(response).to have_http_status(:ok)
    end

    it "updates the form description" do
      patch conference_form_description_path(conference, form_description), params: {form_description: {head: '- Changed'}}

      expect(response).to redirect_to(conference_form_description_path(conference, form_description))
      expect(form_description.reload.head).to eq('- Changed')
    end

    it "renders fallback_options as JSON" do
      form_description.update!(fallback_options: [{'value' => 'opt1', 'name' => 'Option 1', 'conditions' => [{'plans' => ['Ruby']}]}])

      get conference_form_description_path(conference, form_description)
      expect(response).to have_http_status(:ok)

      json = Nokogiri::HTML(response.body).css('pre').map(&:text).join
      expect(JSON.parse(json)).to eq([{'value' => 'opt1', 'name' => 'Option 1', 'conditions' => [{'plans' => ['Ruby']}]}])
    end
  end
end
