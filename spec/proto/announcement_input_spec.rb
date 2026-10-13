# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AnnouncementInput rules' do # rubocop:disable RSpec/DescribeClass
  def input_accepts?(attribute, value)
    Protovalidate.collect_violations(Rk::SponsorApp::AnnouncementInput.new(attribute => value)).none? { it.field_path == attribute.to_s }
  end

  def announcement_accepts?(attribute, value)
    FactoryBot.build(:announcement, attribute => value).tap(&:validate).errors[attribute].empty?
  end

  it 'takes announcements in the locales the app is available in' do
    rules = Google::Protobuf::DescriptorPool.generated_pool.lookup('buf.validate.field')
      .get(Rk::SponsorApp::AnnouncementInput.descriptor.lookup('locale').options)

    expect(rules.string.in.to_a).to match_array(I18n.available_locales.map(&:to_s))
  end

  # Announcement keeps this check for the HAML form, so the two must agree on these samples.
  ['Booth setup', '', ' ', "\t\n", "　"].each do |value|
    it "judges title #{value.inspect} as Announcement does" do
      expect(input_accepts?(:title, value)).to eq(announcement_accepts?(:title, value))
    end
  end
end
