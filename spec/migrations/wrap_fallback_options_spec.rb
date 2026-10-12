# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261012000000_wrap_fallback_options')

RSpec.describe WrapFallbackOptions do
  let(:form_description) { FactoryBot.create(:form_description) }

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(direction) }
  end

  def store(document)
    FormDescription.where(id: form_description.id).update_all(['fallback_options = ?::jsonb', JSON.generate(document)]) # rubocop:disable Rails/SkipsModelValidations
  end

  def stored
    JSON.parse(FormDescription.where(id: form_description.id).pick(Arel.sql('fallback_options::text AS document')))
  end

  def column_default
    FormDescription.connection.select_value(<<~SQL)
      SELECT column_default FROM information_schema.columns
      WHERE table_name = 'form_descriptions' AND column_name = 'fallback_options'
    SQL
  end

  describe 'up' do
    before do
      form_description
      migrate(:down)
    end

    it 'wraps an array of options' do
      store([{value: 'gold', name: 'Gold', conditions: [{plans: ['Ruby'], booth_request: true}], priority_human: ['Gold']}])
      migrate(:up)

      expect(stored).to eq('options' => [
        {'value' => 'gold', 'name' => 'Gold', 'conditions' => [{'plans' => ['Ruby'], 'booth_request' => true}], 'priority_human' => ['Gold']},
      ])
      expect(form_description.reload.fallback_options.options.first.conditions.first)
        .to have_attributes(plans: ['Ruby'], booth_request: true)
    end

    it 'turns a {value => name} Hash into options' do
      store({'gold' => 'Gold', 'silver' => 'Silver'})
      migrate(:up)

      expect(stored).to eq('options' => [{'value' => 'gold', 'name' => 'Gold'}, {'value' => 'silver', 'name' => 'Silver'}])
    end

    it 'turns {} into no options' do
      store({})
      migrate(:up)

      expect(stored).to eq('options' => [])
      expect(form_description.reload.fallback_options).to eq(Rk::SponsorApp::Internal::FallbackOptions.new)
    end

    it 'defaults the column to no options' do
      migrate(:up)

      expect(column_default).to eq(%('{"options": []}'::jsonb))
    end
  end

  describe 'down' do
    it 'unwraps the options into the array, in their .proto field names' do
      form_description.update!(fallback_options: Rk::SponsorApp::Internal::FallbackOptions.new(options: [
        Rk::SponsorApp::Internal::FallbackOption.new(
          value: 'gold',
          name: 'Gold',
          conditions: [Rk::SponsorApp::Internal::FallbackOption::Condition.new(booth_request: false)],
          priority_human: ['Gold'],
        ),
        Rk::SponsorApp::Internal::FallbackOption.new(value: 'withdraw', name: 'Withdraw'),
      ]))
      migrate(:down)

      expect(stored).to eq([
        {'value' => 'gold', 'name' => 'Gold', 'conditions' => [{'booth_request' => false}], 'priority_human' => ['Gold']},
        {'value' => 'withdraw', 'name' => 'Withdraw'},
      ])
      expect(column_default).to eq("'{}'::jsonb")
    end
  end
end
