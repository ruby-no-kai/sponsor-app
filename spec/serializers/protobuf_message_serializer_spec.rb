# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProtobufMessageSerializer do
  let(:filter) do
    Rk::SponsorApp::Internal::BroadcastRecipientFilter.new(
      current_sponsors: Rk::SponsorApp::Internal::BroadcastRecipientFilter::CurrentSponsors.new(
        locale: 'ja',
        plan_id: 3,
        status: :SPONSORSHIP_STATUS_ACTIVE,
      ),
    )
  end

  def round_trip(arguments)
    ActiveJob::Arguments.deserialize(JSON.parse(JSON.generate(ActiveJob::Arguments.serialize(arguments))))
  end

  it 'round-trips a message through a job payload' do
    expect(round_trip([filter, [filter]])).to eq([filter, [filter]])
  end

  it 'stores the full name and ProtoJSON of the message, in .proto field names' do
    expect(ActiveJob::Arguments.serialize([filter])).to eq([
      {
        '_aj_serialized' => 'ProtobufMessageSerializer',
        'message' => 'rubykaigi.sponsor_app.internal.BroadcastRecipientFilter',
        'json' => '{"current_sponsors":{"locale":"ja","plan_id":"3","status":"SPONSORSHIP_STATUS_ACTIVE"}}',
      },
    ])
  end

  it 'ignores fields unknown to this release' do
    argument = {
      '_aj_serialized' => 'ProtobufMessageSerializer',
      'message' => 'rubykaigi.sponsor_app.internal.BroadcastRecipientFilter',
      'json' => '{"current_sponsors":{"locale":"ja","plan_id":"3","status":"SPONSORSHIP_STATUS_ACTIVE","future_field":true}}',
    }

    expect(ActiveJob::Arguments.deserialize([argument])).to eq([filter])
  end

  it 'refuses a message name missing from the descriptor pool' do
    argument = {
      '_aj_serialized' => 'ProtobufMessageSerializer',
      'message' => 'rubykaigi.sponsor_app.internal.Missing',
      'json' => '{}',
    }

    expect { ActiveJob::Arguments.deserialize([argument]) }.to raise_error(ActiveJob::DeserializationError, /unknown protobuf message/)
  end
end
