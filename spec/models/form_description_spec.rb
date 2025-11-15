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
      form.fallback_options = '{"option1": "First Option", "option2": "Second Option"}'
      form.save!

      expect(form.fallback_options).to eq({'option1' => 'First Option', 'option2' => 'Second Option'})
    end

    it 'accepts hash directly' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = {'option1' => 'First Option', 'option2' => 'Second Option'}
      form.save!

      expect(form.fallback_options).to eq({'option1' => 'First Option', 'option2' => 'Second Option'})
    end

    it 'handles blank string as empty hash' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = ''
      form.save!

      expect(form.fallback_options).to eq({})
    end

    it 'handles empty string as empty hash' do
      form = FactoryBot.build(:form_description, conference:, locale: 'en')
      form.fallback_options = '   '
      form.save!

      expect(form.fallback_options).to eq({})
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

      expect(form.fallback_options).to eq({})
    end
  end
end
