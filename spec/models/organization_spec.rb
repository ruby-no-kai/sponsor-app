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
end
