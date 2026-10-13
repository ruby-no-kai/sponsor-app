# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organization, type: :model do
  describe '#slug' do
    it 'returns the domain' do
      organization = FactoryBot.build_stubbed(:organization, domain: 'example.com')
      expect(organization.slug).to eq('example.com')
    end

    it 'matches the domain value' do
      organization = FactoryBot.build_stubbed(:organization, domain: 'test.org')
      expect(organization.slug).to eq(organization.domain)
    end
  end

  describe 'domain' do
    it 'is unique across organizations' do
      FactoryBot.create(:organization, domain: 'example.invalid')
      organization = FactoryBot.build(:organization, domain: 'example.invalid')

      expect(organization).not_to be_valid
      expect(organization.errors.details[:domain]).to eq([{error: :taken, value: 'example.invalid'}])
    end
  end

  describe '#sponsorship_count' do
    let(:organization) { FactoryBot.create(:organization) }

    before do
      2.times do
        FactoryBot.build(:sponsorship, conference: FactoryBot.create(:conference), plan: nil).tap do |sponsorship|
          sponsorship.organization = organization
          sponsorship.save!
        end
      end
      organization.sponsorships.first.update!(withdrawn_at: Time.current)
    end

    it 'counts every sponsorship, withdrawn ones included' do
      expect(organization.sponsorship_count).to eq(2)
    end

    it 'reads the count with_sponsorship_count loaded, querying nothing' do
      loaded = described_class.with_sponsorship_count.find(organization.id)

      expect(query_count { expect(loaded.sponsorship_count).to eq(2) }).to eq(0)
    end
  end
end
