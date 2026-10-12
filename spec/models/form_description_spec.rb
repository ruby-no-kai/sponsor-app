# frozen_string_literal: true

require 'rails_helper'
require 'jsonnet'

RSpec.describe FormDescription, type: :model do
  let(:conference) { FactoryBot.create(:conference) }

  describe '#to_param' do
    it 'returns locale instead of id' do
      form = FactoryBot.create(:form_description, conference:, locale: 'en')
      expect(form.to_param).to eq('en')
    end

    it 'returns different locales correctly' do
      form_en = FactoryBot.create(:form_description, conference:, locale: 'en')
      form_ja = FactoryBot.create(:form_description, conference:, locale: 'ja')

      expect(form_en.to_param).to eq('en')
      expect(form_ja.to_param).to eq('ja')
    end
  end

  describe '#render_markdown callback' do
    it 'renders markdown fields to HTML on save' do
      form = FactoryBot.create(
        :form_description,
        conference:,
        locale: 'en',
        head: '# Welcome',
        plan_help: '## Plans',
      )

      expect(form.head_html).to include('<h1')
      expect(form.head_html).to include('Welcome')
      expect(form.plan_help_html).to include('<h2')
      expect(form.plan_help_html).to include('Plans')
    end

    it 'renders all markdown fields' do
      form = FactoryBot.create(
        :form_description,
        conference:,
        locale: 'en',
        head: '# Head',
        plan_help: '# Plan',
        booth_help: '# Booth',
        policy_help: '# Policy',
        ticket_help: '# Ticket',
      )

      expect(form.head_html).to be_present
      expect(form.plan_help_html).to be_present
      expect(form.booth_help_html).to be_present
      expect(form.policy_help_html).to be_present
      expect(form.ticket_help_html).to be_present
    end
  end

  describe '#fallback_options' do
    let(:fallback_options) do
      Rk::SponsorApp::Internal::FallbackOptions.new(options: [
        Rk::SponsorApp::Internal::FallbackOption.new(
          value: 'gold',
          name: 'Change to Gold',
          conditions: [Rk::SponsorApp::Internal::FallbackOption::Condition.new(plans: ['Platinum'], booth_request: true)],
          priority_human: ['{plan}!no_booth', 'Gold'],
        ),
        Rk::SponsorApp::Internal::FallbackOption.new(value: 'withdraw', name: 'Withdraw'),
      ])
    end

    def stored_document(form)
      JSON.parse(described_class.where(id: form.id).pick(Arel.sql('fallback_options::text AS document')))
    end

    def store_document(form, document)
      described_class.where(id: form.id).update_all(['fallback_options = ?::jsonb', JSON.generate(document)]) # rubocop:disable Rails/SkipsModelValidations
    end

    before { FactoryBot.create(:plan, conference:, name: 'Platinum') }

    it 'is an empty message by default' do
      expect(described_class.new.fallback_options).to eq(Rk::SponsorApp::Internal::FallbackOptions.new)
    end

    it 'round-trips the message through the column' do
      form = FactoryBot.create(:form_description, conference:, fallback_options:)

      expect(described_class.find(form.id).fallback_options).to eq(fallback_options)
    end

    it 'stores ProtoJSON in the .proto field names with every field present' do
      form = FactoryBot.create(:form_description, conference:, fallback_options:)

      expect(stored_document(form).fetch('options')).to eq([
        {
          'value' => 'gold', 'name' => 'Change to Gold',
          'conditions' => [{'plans' => ['Platinum'], 'booth_request' => true}],
          'priority_human' => ['{plan}!no_booth', 'Gold'],
        },
        {'value' => 'withdraw', 'name' => 'Withdraw', 'conditions' => [], 'priority_human' => []},
      ])
    end

    it 'leaves a loaded record unchanged' do
      form = FactoryBot.create(:form_description, conference:, fallback_options:)

      expect(described_class.find(form.id).changed?).to be(false)
    end

    it 'reads a document carrying a field the message does not declare' do
      form = FactoryBot.create(:form_description, conference:)
      store_document(form, {options: [{value: 'gold', name: 'Gold', retiredField: true}]})

      expect(described_class.find(form.id).fallback_options.options.map(&:value)).to eq(['gold'])
    end

    it 'reads a document in the lowerCamelCase JSON names' do
      form = FactoryBot.create(:form_description, conference:)
      store_document(form, {options: [{value: 'gold', name: 'Gold', priorityHuman: ['Gold'], conditions: [{boothRequest: false}]}]})

      option = described_class.find(form.id).fallback_options.options.first
      expect(option.priority_human.to_a).to eq(['Gold'])
      expect(option.conditions.first).to have_attributes(has_booth_request?: true, booth_request: false)
    end

    it 'reads a document in the .proto field names, as the migration leaves it' do
      form = FactoryBot.create(:form_description, conference:)
      store_document(form, {options: [{value: 'gold', name: 'Gold', priority_human: ['Gold'], conditions: [{booth_request: false}]}]})

      option = described_class.find(form.id).fallback_options.options.first
      expect(option.priority_human.to_a).to eq(['Gold'])
      expect(option.conditions.first).to have_attributes(has_booth_request?: true, booth_request: false)
    end

    it 'casts a Hash to the message' do
      form = described_class.new(fallback_options: {options: [{value: 'gold', name: 'Gold', conditions: [{plans: ['Platinum']}]}]})

      expect(form.fallback_options).to be_a(Rk::SponsorApp::Internal::FallbackOptions)
      expect(form.fallback_options.options.first.conditions.first.plans.to_a).to eq(['Platinum'])
    end

    it 'accepts options sharing a value under different conditions' do
      platinum = ->(booth_request) { Rk::SponsorApp::Internal::FallbackOption::Condition.new(plans: ['Platinum'], booth_request:) }
      form = FactoryBot.build(:form_description, conference:, fallback_options: Rk::SponsorApp::Internal::FallbackOptions.new(options: [
        Rk::SponsorApp::Internal::FallbackOption.new(value: 'gold', name: 'Gold, booth or not', conditions: [platinum.(true)]),
        Rk::SponsorApp::Internal::FallbackOption.new(value: 'gold', name: 'Gold', conditions: [platinum.(false)]),
      ]))

      expect(form).to be_valid
    end

    describe 'buf.validate rules' do
      let(:form) { FactoryBot.build(:form_description, conference:, fallback_options:) }

      it 'reports a broken rule on the attribute, naming the field' do
        form.fallback_options.options << Rk::SponsorApp::Internal::FallbackOption.new(value: '', name: 'Nameless')

        expect(form).not_to be_valid
        expect(form.errors[:fallback_options]).to eq(['options[2].value: value is required'])
      end

      it 'reports a blank name' do
        form.fallback_options.options.first.name = '  '

        expect(form).not_to be_valid
        expect(form.errors[:fallback_options]).to eq(['options[0].name: value must not be blank'])
      end

      it 'rejects options sharing both value and conditions' do
        form.fallback_options.options << Rk::SponsorApp::Internal::FallbackOption.new(value: 'withdraw', name: 'Withdraw again')

        expect(form).not_to be_valid
        expect(form.errors[:fallback_options]).to eq(['options: options sharing a value must differ in their conditions'])
      end

      it 'reports a list too long to check for repeats by its size alone' do
        form.fallback_options = Rk::SponsorApp::Internal::FallbackOptions.new(
          options: Array.new(100) { |i| Rk::SponsorApp::Internal::FallbackOption.new(value: "option#{i}", name: 'Option') },
        )

        expect(form).not_to be_valid
        expect(form.errors[:fallback_options]).to eq(['options: must contain no more than 50 item(s)'])
      end

      it 'rejects a condition that names neither plans nor a booth request' do
        form.fallback_options.options.first.conditions << Rk::SponsorApp::Internal::FallbackOption::Condition.new

        expect(form).not_to be_valid
        expect(form.errors[:fallback_options]).to eq(['options[0].conditions[1]: a condition must name plans or a booth request'])
      end

      it 'is checked by save' do
        form.fallback_options.options.first.value = ''

        expect { form.save! }.to raise_error(ActiveRecord::RecordInvalid, /options\[0\]\.value: value is required/)
      end
    end

    it 'rejects a condition naming a plan the conference does not have' do
      fallback_options.options.first.conditions.first.plans << 'Diamond'
      form = FactoryBot.build(:form_description, conference:, fallback_options:)

      expect(form).not_to be_valid
      expect(form.errors[:fallback_options]).to eq(['option 1, condition 1 names Diamond, which is not a plan of the conference'])
      expect(form.errors.details[:fallback_options]).to eq([{error: :unknown_plan}])
    end

    it 'names every plan of a condition the conference does not have in one error' do
      fallback_options.options.first.conditions.first.plans.push('Diamond', 'Emerald')
      form = FactoryBot.build(:form_description, conference:, fallback_options:)

      expect(form).not_to be_valid
      expect(form.errors[:fallback_options]).to eq(['option 1, condition 1 names Diamond and Emerald, which are not plans of the conference'])
    end
  end

  describe 'the fallback options db/seeds.rb loads' do
    %w[en ja].each do |locale|
      it "decodes misc/fallback_options_#{locale}.jsonnet into a message breaking no rule" do
        json = Jsonnet::VM.evaluate_file(Rails.root.join("misc/fallback_options_#{locale}.jsonnet").to_s)
        fallback_options = Rk::SponsorApp::Internal::FallbackOptions.decode_json(json)

        expect(fallback_options.options.size).to eq(12)
        expect(Protovalidate.collect_violations(fallback_options)).to be_empty
      end
    end
  end
end
