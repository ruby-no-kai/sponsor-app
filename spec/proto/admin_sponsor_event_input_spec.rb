# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminSponsorEventInput rules' do # rubocop:disable RSpec/DescribeClass
  def input_accepts?(attribute, value)
    Protovalidate.collect_violations(Rk::SponsorApp::AdminSponsorEventInput.new(attribute => value)).none? { it.field_path == attribute.to_s }
  end

  # In the update context, as creating an event fills in a blank slug.
  def event_accepts?(attribute, value)
    FactoryBot.build(:sponsor_event, attribute => value).tap { it.validate(:update) }.errors[attribute].empty?
  end

  # SponsorEvent keeps these checks for the HAML forms, so the two must agree on these samples.
  {
    title: ['Ruby Night', '', ' ', "\t\n", "　"],
    slug: ['example.com-1', '', ' ', " "],
    url: [
      'https://night.example.invalid',
      'http://night.example.invalid',
      'http://',
      '',
      'night.example.invalid',
      'ftp://night.example.invalid',
      ' https://night.example.invalid',
      'HTTPS://night.example.invalid',
      "javascript:alert(1)//\nhttps://",
    ],
  }.each do |attribute, samples|
    samples.each do |value|
      it "judges #{attribute} #{value.inspect} as SponsorEvent does" do
        expect(input_accepts?(attribute, value)).to eq(event_accepts?(attribute, value))
      end
    end
  end
end
