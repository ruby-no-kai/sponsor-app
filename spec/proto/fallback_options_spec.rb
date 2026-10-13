# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FallbackOption messages' do # rubocop:disable RSpec/DescribeClass
  def rules(descriptor, field_names)
    fields = field_names.index_with { Google::Protobuf::FieldOptions.encode(descriptor.lookup(it).options) }
    [fields, Google::Protobuf::MessageOptions.encode(descriptor.options)]
  end

  it "applies the stored option's rules to the published option" do
    [
      [Rk::SponsorApp::FallbackOption, Rk::SponsorApp::Internal::FallbackOption],
      [Rk::SponsorApp::FallbackOption::Condition, Rk::SponsorApp::Internal::FallbackOption::Condition],
    ].each do |published, stored|
      shared = published.descriptor.map(&:name) & stored.descriptor.map(&:name)

      expect(rules(published.descriptor, shared)).to eq(rules(stored.descriptor, shared))
    end
  end

  it "checks an input's options by the stored options' rules" do
    input_options = Rk::SponsorApp::FormDescriptionInput.descriptor.lookup('fallback_options').options
    stored_options = Rk::SponsorApp::Internal::FallbackOptions.descriptor.lookup('options').options

    expect(Google::Protobuf::FieldOptions.encode(input_options)).to eq(Google::Protobuf::FieldOptions.encode(stored_options))
  end

  it 'takes form descriptions in the locales the app is available in' do
    rules = Google::Protobuf::DescriptorPool.generated_pool.lookup('buf.validate.field')
      .get(Rk::SponsorApp::FormDescriptionInput.descriptor.lookup('locale').options)

    expect(rules.string.in.to_a).to match_array(I18n.available_locales.map(&:to_s))
  end
end
