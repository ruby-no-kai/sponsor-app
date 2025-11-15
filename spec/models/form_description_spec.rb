require 'rails_helper'

RSpec.describe FormDescription, type: :model do
  let(:conference) { FactoryBot.create(:conference) }

  describe '#render_markdown callback' do
    it 'renders markdown fields to HTML on save' do
      form = FactoryBot.create(:form_description,
        conference:,
        locale: 'en',
        head: '# Welcome',
        plan_help: '## Plans'
      )

      expect(form.head_html).to include('<h1')
      expect(form.head_html).to include('Welcome')
      expect(form.plan_help_html).to include('<h2')
      expect(form.plan_help_html).to include('Plans')
    end

    it 'renders all markdown fields' do
      form = FactoryBot.create(:form_description,
        conference:,
        locale: 'en',
        head: '# Head',
        plan_help: '# Plan',
        booth_help: '# Booth',
        policy_help: '# Policy',
        ticket_help: '# Ticket'
      )

      expect(form.head_html).to be_present
      expect(form.plan_help_html).to be_present
      expect(form.booth_help_html).to be_present
      expect(form.policy_help_html).to be_present
      expect(form.ticket_help_html).to be_present
    end
  end

  describe '#fallback_options=' do
    it 'accepts JSON string and parses it' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = '[{"value": "option1", "name": "First Option"}, {"value": "option2", "name": "Second Option"}]'
      form.save!

      expect(form.fallback_options).to all(be_a(FormDescription::FallbackOption))
      expect(form.fallback_options[0].value).to eq('option1')
      expect(form.fallback_options[0].name).to eq('First Option')
      expect(form.fallback_options[1].value).to eq('option2')
      expect(form.fallback_options[1].name).to eq('Second Option')
    end

    it 'accepts array directly' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = [{'value' => 'option1', 'name' => 'First Option'}, {'value' => 'option2', 'name' => 'Second Option'}]
      form.save!

      expect(form.fallback_options).to all(be_a(FormDescription::FallbackOption))
      expect(form.fallback_options[0].value).to eq('option1')
      expect(form.fallback_options[0].name).to eq('First Option')
    end

    it 'handles blank string as empty array' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = ''
      form.save!

      expect(form.fallback_options).to eq([])
    end

    it 'handles empty string as empty array' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = '   '
      form.save!

      expect(form.fallback_options).to eq([])
    end

    it 'adds validation error for invalid JSON' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = '{invalid json}'

      expect(form).not_to be_valid
      expect(form.errors[:fallback_options]).to include('must be valid JSON')
    end

    it 'handles nil as is (uses default)' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = nil
      form.save!

      expect(form.fallback_options).to eq([])
    end

    it 'adds validation error for non-array JSON' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = '{"key": "value"}'

      expect(form).not_to be_valid
      expect(form.errors[:fallback_options]).to include('must be an array of objects with "value" and "name" keys')
    end

    it 'adds validation error for array items missing required keys' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = '[{"value": "option1"}]'

      expect(form).not_to be_valid
      expect(form.errors[:fallback_options]).to include('must be an array of objects with "value" and "name" keys')
    end

    it 'adds validation error for array with non-hash items' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = '["string1", "string2"]'

      expect(form).not_to be_valid
      expect(form.errors[:fallback_options]).to include('must be an array of objects with "value" and "name" keys')
    end
  end
end
