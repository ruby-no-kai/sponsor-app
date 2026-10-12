# frozen_string_literal: true

require 'rails_helper'
require 'open3'

RSpec.describe 'sponsor_app-proto' do # rubocop:disable RSpec/DescribeClass
  let(:gem_lib) { Rails.root.join('gen/proto/ruby/lib').to_s }

  it 'registers org.rubykaigi.sponsor_app.Conference as Rk::SponsorApp::Conference' do
    descriptor = Google::Protobuf::DescriptorPool.generated_pool.lookup('org.rubykaigi.sponsor_app.Conference')
    expect(descriptor.msgclass).to eq(Rk::SponsorApp::Conference)
  end

  describe 'ProtoJSON' do
    let(:message) do
      Rk::SponsorApp::Conference.new(
        slug: 'rubykaigi2026',
        name: 'RubyKaigi 2026',
        contact_email_address: 'sponsorship@rubykaigi.invalid',
        application_opens_at: Google::Protobuf::Timestamp.new(seconds: Time.utc(2026, 1, 15).to_i),
        booths_offered: true,
      )
    end

    let(:json) { Rk::SponsorApp::Conference.encode_json(message, preserve_proto_fieldnames: true) }

    it 'emits proto field names with preserve_proto_fieldnames' do
      expect(JSON.parse(json)).to eq(
        'slug' => 'rubykaigi2026',
        'name' => 'RubyKaigi 2026',
        'contact_email_address' => 'sponsorship@rubykaigi.invalid',
        'application_opens_at' => '2026-01-15T00:00:00Z',
        'booths_offered' => true,
      )
    end

    it 'emits lowerCamelCase names by default' do
      expect(JSON.parse(Rk::SponsorApp::Conference.encode_json(message))).to include('contactEmailAddress', 'applicationOpensAt')
    end

    it 'round-trips with the presence of each optional timestamp intact' do
      decoded = Rk::SponsorApp::Conference.decode_json(json)

      expect(decoded).to eq(message)
      expect(decoded.has_application_opens_at?).to be(true)
      expect(decoded.has_application_closes_at?).to be(false)
      expect(decoded.application_closes_at).to be_nil
    end
  end

  describe 'entry file' do
    # A fresh process, so only what the entry file itself requires is counted.
    let(:loaded_from_gem) do
      script = <<~RUBY
        before = $LOADED_FEATURES.dup
        require 'sponsor_app-proto'
        puts($LOADED_FEATURES - before)
      RUBY
      out, status = Open3.capture2e(
        {'BUNDLE_GEMFILE' => Rails.root.join('Gemfile').to_s},
        RbConfig.ruby, '-rbundler/setup', '-e', script,
        chdir: Rails.root.to_s,
      )
      raise "entry file failed to load:\n#{out}" unless status.success?

      out.lines(chomp: true).filter_map { |path| path.delete_prefix("#{gem_lib}/") if path.start_with?("#{gem_lib}/") }
    end

    it 'loads generated files of org.rubykaigi packages only' do
      expect(loaded_from_gem).to include('org/rubykaigi/sponsor_app/conference_pb.rb')
      expect(loaded_from_gem - ['sponsor_app-proto.rb']).to all(start_with('org/rubykaigi/'))
    end

    it 'has no generated copy of a package that a gem owns' do
      expect(Dir.glob('**/*_pb.rb', base: gem_lib)).to all(start_with('org/rubykaigi/'))
    end
  end
end
