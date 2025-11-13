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
end
