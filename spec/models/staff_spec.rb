# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Staff, type: :model do
  let(:conference) do
    FactoryBot.build(:conference, allow_restricted_access: true, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
  end

  describe '#conference_accessible?' do
    it 'admits unrestricted staff to every conference' do
      staff = FactoryBot.build(:staff)

      expect(staff).not_to be_restricted
      expect(staff.conference_accessible?(FactoryBot.build(:conference))).to be(true)
    end

    it 'admits restricted staff to a conference of their repository that allows them' do
      staff = FactoryBot.build(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted'])

      expect(staff).to be_restricted
      expect(staff.conference_accessible?(conference)).to be(true)
    end

    it 'turns restricted staff away from a conference that does not allow them' do
      staff = FactoryBot.build(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted'])
      conference.allow_restricted_access = false

      expect(staff.conference_accessible?(conference)).to be(false)
    end

    it 'turns restricted staff away from a conference of another repository' do
      staff = FactoryBot.build(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-other'])

      expect(staff.conference_accessible?(conference)).to be(false)
      expect(staff.conference_accessible?(FactoryBot.build(:conference, allow_restricted_access: true))).to be(false)
    end
  end
end
