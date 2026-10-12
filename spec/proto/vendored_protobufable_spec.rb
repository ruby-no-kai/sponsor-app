# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'proto/protobufable' do # rubocop:disable RSpec/DescribeClass
  it "matches the protobufable gem's own copies byte for byte" do
    gem_proto = Pathname(Gem.loaded_specs.fetch('protobufable').full_gem_path).join('proto/protobufable')
    vendored = Rails.root.join('proto/protobufable')

    expect(vendored.children.map(&:basename)).to match_array(gem_proto.children.map(&:basename))
    vendored.children.each do |path|
      expect(path.binread).to eq(gem_proto.join(path.basename).binread), "#{path} differs from the gem's copy"
    end
  end
end
