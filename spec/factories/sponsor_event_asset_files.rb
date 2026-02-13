FactoryBot.define do
  factory :sponsor_event_asset_file do
    sponsorship
    prefix { "test/events/" }
    extension { "png" }
    checksum_sha256 { "abc123" }
  end
end
