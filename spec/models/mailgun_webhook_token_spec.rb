# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MailgunWebhookToken do
  describe '.consume' do
    it 'returns true only for the first use of a token' do
      expect(described_class.consume(token: 'a', signed_at: Time.zone.now)).to be(true)
      expect(described_class.consume(token: 'a', signed_at: Time.zone.now)).to be(false)
    end

    it 'deletes tokens past MAX_AGE' do
      described_class.consume(token: 'old', signed_at: 2.hours.ago)
      described_class.consume(token: 'recent', signed_at: 10.minutes.ago)

      described_class.consume(token: 'new', signed_at: Time.zone.now)
      expect(described_class.pluck(:token)).to contain_exactly('recent', 'new')
    end
  end

  describe '.acceptable_time?' do
    let(:now) { Time.zone.now }

    it 'allows small future skew only' do
      expect(described_class.acceptable_time?(now + 1.minute, now:)).to be(true)
      expect(described_class.acceptable_time?(now + 10.minutes, now:)).to be(false)
      expect(described_class.acceptable_time?(now - 59.minutes, now:)).to be(true)
      expect(described_class.acceptable_time?(now - 61.minutes, now:)).to be(false)
    end
  end
end
