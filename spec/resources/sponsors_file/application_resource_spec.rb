# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SponsorsFile::ApplicationResource do
  it "writes the fields in the message's declaration order, as Symbols" do
    resource = Class.new(described_class) do
      with_protobuf Rk::SponsorApp::SponsorsFile::Host do
        attributes :url, :name, :slug
      end
    end
    host = Struct.new(:slug, :name, :url).new('contoso.invalid', 'Contoso', 'https://contoso.invalid/')

    expect(resource.new(host).serializable_hash.keys).to eq(%i(slug name url))
    expect(resource.new([host, host]).serializable_hash.map(&:keys)).to eq([%i(slug name url)] * 2)
  end
end
