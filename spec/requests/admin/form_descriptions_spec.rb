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

    it "reports malformed fallback_options JSON on the form" do
      expect do
        post conference_form_descriptions_path(conference), params: {form_description: {locale: 'ja', fallback_options: '['}}
      end.not_to change(conference.form_descriptions, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('is not a FallbackOptions message')
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
      FactoryBot.create(:plan, conference:, name: 'Ruby')
      form_description.update!(fallback_options: {options: [{value: 'opt1', name: 'Option 1', conditions: [{plans: ['Ruby']}]}]})

      get conference_form_description_path(conference, form_description)
      expect(response).to have_http_status(:ok)

      json = Nokogiri::HTML(response.body).css('pre').map(&:text).join
      expect(JSON.parse(json)).to eq('options' => [{'value' => 'opt1', 'name' => 'Option 1', 'conditions' => [{'plans' => ['Ruby']}]}])
    end

    describe "fallback_options" do
      before { FactoryBot.create(:plan, conference:, name: 'Platinum') }

      def submit(fallback_options)
        patch conference_form_description_path(conference, form_description), params: {form_description: {head: '- Changed', fallback_options:}}
      end

      it "stores the message the JSON describes, in either field name spelling" do
        submit('{"options": [{"value": "gold", "name": "Gold", "conditions": [{"plans": ["Platinum"], "booth_request": true}], "priorityHuman": ["Gold"]}]}')

        expect(response).to redirect_to(conference_form_description_path(conference, form_description))
        expect(form_description.reload.fallback_options).to eq(Rk::SponsorApp::Internal::FallbackOptions.new(options: [
          Rk::SponsorApp::Internal::FallbackOption.new(
            value: 'gold',
            name: 'Gold',
            conditions: [Rk::SponsorApp::Internal::FallbackOption::Condition.new(plans: ['Platinum'], booth_request: true)],
            priority_human: ['Gold'],
          ),
        ]))
      end

      it "clears the options when left blank" do
        form_description.update!(fallback_options: {options: [{value: 'gold', name: 'Gold'}]})

        submit('')

        expect(form_description.reload.fallback_options.options).to be_empty
      end

      it "shows the stored options in the .proto field names" do
        form_description.update!(fallback_options: {options: [{value: 'gold', name: 'Gold', priority_human: ['Gold']}]})

        get edit_conference_form_description_path(conference, form_description)

        textarea = Nokogiri::HTML(response.body).at_css('textarea[name="form_description[fallback_options]"]')
        expect(JSON.parse(textarea.text)).to eq('options' => [{'value' => 'gold', 'name' => 'Gold', 'priority_human' => ['Gold']}])
      end

      [
        ['malformed JSON', '{"options": ['],
        ['a key the message does not declare', '{"options": [{"value": "gold", "name": "Gold", "label": "x"}]}'],
        ['a value of the wrong type', '{"options": [{"value": "gold", "name": "Gold", "conditions": "Platinum"}]}'],
        ['a null option', '{"options": [null]}'],
        ['an option that is not an object', '{"options": [1]}'],
        ['an option that is a list', '{"options": [["a"]]}'],
        ['conditions given as one object', '{"options": [{"value": "a", "name": "A", "conditions": {"plans": ["Platinum"]}}]}'],
        ['a condition that is not an object', '{"options": [{"value": "a", "name": "A", "conditions": [1]}]}'],
        ['a condition given as a string', '{"options": [{"value": "a", "name": "A", "conditions": ["x"]}]}'],
      ].each do |description, json|
        it "reports #{description} on the form, keeping what was typed" do
          submit(json)

          expect(response).to have_http_status(:ok)
          page = Nokogiri::HTML(response.body)
          expect(page.at_css('.alert-danger').text).to include('Fallback Options is not a FallbackOptions message')
          expect(page.at_css('textarea[name="form_description[fallback_options]"]').text.strip).to eq(json)
          expect(form_description.reload.head).not_to eq('- Changed')
        end
      end

      it "reports a broken rule on the form" do
        submit('{"options": [{"value": "", "name": "Gold"}]}')

        expect(response).to have_http_status(:ok)
        expect(Nokogiri::HTML(response.body).at_css('.alert-danger').text).to include('options[0].value: value is required')
      end
    end
  end
end
