# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EditingHistoryChange do
  it 'reads an addition, which has no old value' do
    change = described_class.new(['+', 'withdrawn_at', '2026-10-01T00:00:00Z'])

    expect(change).to have_attributes(operation: '+', path: 'withdrawn_at', old_value?: false, new_value?: true,
      new_value: '2026-10-01T00:00:00Z')
    expect { change.old_value }.to raise_error(ArgumentError)
  end

  it 'reads a removal, which has no new value' do
    change = described_class.new(['-', 'tags[1]', nil])

    expect(change).to have_attributes(operation: '-', path: 'tags[1]', old_value?: true, new_value?: false, old_value: nil)
    expect { change.new_value }.to raise_error(ArgumentError)
  end

  it 'reads a change, which has both' do
    change = described_class.new(['~', 'contact.email', 'a@example.invalid', 'b@example.invalid'])

    expect(change).to have_attributes(old_value: 'a@example.invalid', new_value: 'b@example.invalid')
  end
end
