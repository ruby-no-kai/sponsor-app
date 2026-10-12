# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ConferenceInput rules' do # rubocop:disable RSpec/DescribeClass
  def input_accepts?(attribute, value)
    Protovalidate.collect_violations(Rk::SponsorApp::ConferenceInput.new(attribute => value)).none? { it.field_path == attribute.to_s }
  end

  def conference_accepts?(attribute, value)
    FactoryBot.build(:conference, attribute => value).tap(&:validate).errors[attribute].empty?
  end

  # Conference keeps these checks for the HAML form, so the two must agree on these samples.
  {
    tito_slug: ['rubykaigi/2026', 'a/b', 'rubykaigi', 'rubykaigi/2026/extra', '/2026', 'rubykaigi/'],
    github_repo: [
      'ruby-no-kai/rubykaigi.org:data/sponsors.yml',
      'ruby-no-kai/rubykaigi.org@master:data/sponsors.yml',
      'repo:path',
      'repo@branch@more:path:more',
      'ruby-no-kai/rubykaigi.org',
      'ruby-no-kai/rubykaigi.org@master',
      ':path',
      'repo:',
    ],
  }.each do |attribute, samples|
    samples.each do |value|
      it "judges #{attribute} #{value.inspect} as Conference does" do
        expect(input_accepts?(attribute, value)).to eq(conference_accepts?(attribute, value))
      end
    end
  end

  # Conference alone rejects a blank repository or path.
  ['repo: ', ' :path', 'a@b: '].each do |value|
    it "leaves github_repo #{value.inspect} for Conference to reject" do
      expect(input_accepts?(:github_repo, value)).to be(true)
      expect(conference_accepts?(:github_repo, value)).to be(false)
    end
  end
end
