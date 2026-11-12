# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvoiceSponsorshipFilter do
  subject(:filter) do
    described_class.new(
      conference:,
      filters: filter_params[:filters],
      locales: filter_params[:locales],
      plan_ids: filter_params[:plan_ids],
      customization_filter: filter_params[:customization_filter],
    )
  end

  let(:conference) { FactoryBot.create(:conference) }
  let!(:first_plan) { FactoryBot.create(:plan, conference:, rank: 2) }
  let!(:second_plan) { FactoryBot.create(:plan, conference:, rank: 1) }
  let!(:second_plan_sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: second_plan, locale: 'ja', accepted_at: Time.current) }
  let!(:custom_sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: first_plan, locale: 'en', accepted_at: Time.current, customization: true) }
  let!(:standard_sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: first_plan, locale: 'ja', accepted_at: Time.current) }
  let(:filter_params) { {} }

  it 'selects all candidates initially and orders output by plan ID then sponsorship ID' do
    expect(filter.locales).to eq(%w[en ja])
    expect(filter.plans).to eq([second_plan, first_plan])
    expect(filter.selected_locales).to eq(%w[en ja])
    expect(filter.selected_plan_ids).to eq([second_plan.id.to_s, first_plan.id.to_s])
    expect(filter.customization_filter).to eq('all')
    expect(filter.sponsorships).to eq([custom_sponsorship, standard_sponsorship, second_plan_sponsorship])
  end

  it 'eager loads billing contacts, plans, and expense reports' do
    expect(filter.sponsorships.first.association(:contact)).to be_loaded
    expect(filter.sponsorships.first.association(:alternate_billing_contact)).to be_loaded
    expect(filter.sponsorships.first.association(:plan)).to be_loaded
    expect(filter.sponsorships.first.association(:expense_report)).to be_loaded
  end

  context 'with blank filters' do
    let(:filter_params) { {filters: '', locales: ['invalid'], plan_ids: []} }

    it 'keeps all candidates selected' do
      expect(filter.sponsorships).to eq([custom_sponsorship, standard_sponsorship, second_plan_sponsorship])
    end
  end

  context 'with submitted filters but no selections' do
    let(:filter_params) { {filters: '1'} }

    it 'keeps both selections empty' do
      expect(filter.selected_locales).to eq([])
      expect(filter.selected_plan_ids).to eq([])
      expect(filter.sponsorships).to be_empty
    end
  end

  context 'with invalid and duplicate candidates' do
    let(:other_plan) { FactoryBot.create(:plan) }
    let(:filter_params) do
      {filters: '1', locales: %w[en invalid en], plan_ids: [first_plan.id.to_s, other_plan.id.to_s, first_plan.id.to_s], customization_filter: 'invalid'}
    end

    it 'keeps only valid selections and defaults customization to all' do
      expect(filter.selected_locales).to eq(['en'])
      expect(filter.selected_plan_ids).to eq([first_plan.id.to_s])
      expect(filter.customization_filter).to eq('all')
      expect(filter.sponsorships).to eq([custom_sponsorship])
    end
  end

  context 'with non-active and other-conference sponsorships' do
    let(:other_plan) { FactoryBot.create(:plan) }

    before do
      FactoryBot.create(:sponsorship, conference:, plan: first_plan, locale: 'pending', accepted_at: nil)
      FactoryBot.create(:sponsorship, conference:, plan: first_plan, locale: 'withdrawn', accepted_at: Time.current, withdrawn_at: Time.current)
      FactoryBot.create(:sponsorship, conference: other_plan.conference, plan: other_plan, locale: 'other', accepted_at: Time.current)
    end

    it 'excludes them from candidates and output' do
      expect(filter.locales).to eq(%w[en ja])
      expect(filter.sponsorships).to eq([custom_sponsorship, standard_sponsorship, second_plan_sponsorship])
    end
  end

  context 'with customization and no filters flag' do
    let(:filter_params) { {customization_filter: 'with'} }

    it 'applies customization independently of the filters flag' do
      expect(filter.sponsorships).to eq([custom_sponsorship])
    end
  end

  context 'without customization' do
    let(:filter_params) { {customization_filter: 'without'} }

    it 'includes only standard sponsorships' do
      expect(filter.sponsorships).to eq([standard_sponsorship, second_plan_sponsorship])
    end
  end
end
