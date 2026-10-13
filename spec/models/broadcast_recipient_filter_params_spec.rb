# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BroadcastRecipientFilterParams do
  filter_class = Rk::SponsorApp::Internal::BroadcastRecipientFilter

  def build(**params)
    described_class.build(ActionController::Parameters.new(params))
  end

  describe '.build' do
    it 'returns nil for none' do
      expect(build(kind: 'none')).to be_nil
    end

    it 'builds current sponsors from the form strings' do
      expect(build(kind: 'all', locale: 'ja', exhibitors: '1', plan_id: '12', status: 'active')).to eq(
        filter_class.new(
          current_sponsors: filter_class::CurrentSponsors.new(
            locale: 'ja',
            exhibitors_only: true,
            plan_id: 12,
            status: :SPONSORSHIP_STATUS_ACTIVE,
          ),
        ),
      )
    end

    it 'leaves blank optional fields of current sponsors unset' do
      sub = build(kind: 'all', locale: '', plan_id: '', status: 'all').current_sponsors

      expect(sub.has_locale?).to be(false)
      expect(sub.has_plan_id?).to be(false)
      expect(sub).to have_attributes(exhibitors_only: false, status: :SPONSORSHIP_STATUS_UNSPECIFIED)
    end

    it 'maps every form status' do
      statuses = {
        nil => :SPONSORSHIP_STATUS_UNSPECIFIED,
        'all' => :SPONSORSHIP_STATUS_UNSPECIFIED,
        'pending' => :SPONSORSHIP_STATUS_PENDING,
        'active' => :SPONSORSHIP_STATUS_ACTIVE,
        'not_accepted' => :SPONSORSHIP_STATUS_NOT_ACCEPTED,
        'accepted' => :SPONSORSHIP_STATUS_ACCEPTED,
        'withdrawn' => :SPONSORSHIP_STATUS_WITHDRAWN,
      }

      expect(statuses.keys.map { build(kind: 'all', status: it).current_sponsors.status }).to eq(statuses.values)
    end

    it 'builds past sponsors from the form strings' do
      expect(build(kind: 'past_sponsors', id: '7', locale: 'en', exclude_current_sponsors: '1', status: 'accepted')).to eq(
        filter_class.new(
          past_sponsors: filter_class::PastSponsors.new(
            conference_id: 7,
            locale: 'en',
            exclude_current_sponsors: true,
            status: :SPONSORSHIP_STATUS_ACCEPTED,
          ),
        ),
      )
    end

    it 'builds manual from the checked sponsorship ids' do
      expect(build(kind: 'manual', sponsorship_ids: %w(3 5)).manual.sponsorship_ids.to_a).to eq([3, 5])
      expect(build(kind: 'manual').manual.sponsorship_ids.to_a).to eq([])
    end

    it 'builds raw with one email per line' do
      expect(build(kind: 'raw', emails: "a@example.com\r\nb@example.com\n").raw.emails.to_a).to eq(%w(a@example.com b@example.com))
    end

    it 'drops params the form does not offer' do
      filter = described_class.build(ActionController::Parameters.new(kind: 'raw', emails: 'a@example.com', bogus: '1'))

      expect(filter).to eq(filter_class.new(raw: filter_class::Raw.new(emails: ['a@example.com'])))
    end

    it 'refuses an unknown kind' do
      expect { build(kind: 'everyone') }.to raise_error(ActionController::BadRequest, /kind/)
      expect { build }.to raise_error(ActionController::BadRequest, /kind/)
    end

    it 'refuses an unknown status' do
      expect { build(kind: 'all', status: 'bogus') }.to raise_error(ActionController::BadRequest, /status/)
      expect { build(kind: 'past_sponsors', id: '1', status: '') }.to raise_error(ActionController::BadRequest, /status/)
    end

    it 'refuses an id that is not an integer' do
      expect { build(kind: 'all', plan_id: 'x') }.to raise_error(ActionController::BadRequest, /id/)
      expect { build(kind: 'past_sponsors') }.to raise_error(ActionController::BadRequest, /id/)
      expect { build(kind: 'manual', sponsorship_ids: %w(1 two)) }.to raise_error(ActionController::BadRequest, /id/)
    end

    it 'refuses an id outside int64' do
      too_large = (2**63).to_s

      expect { build(kind: 'all', plan_id: too_large) }.to raise_error(ActionController::BadRequest, /id/)
      expect { build(kind: 'past_sponsors', id: too_large) }.to raise_error(ActionController::BadRequest, /id/)
      expect { build(kind: 'manual', sponsorship_ids: ['1', too_large]) }.to raise_error(ActionController::BadRequest, /id/)
      expect(build(kind: 'past_sponsors', id: (2**63 - 1).to_s).past_sponsors.conference_id).to eq(2**63 - 1)
    end

    it 'refuses a locale that is not a string' do
      expect { build(kind: 'all', locale: 1) }.to raise_error(ActionController::BadRequest, /locale/)
      expect { build(kind: 'past_sponsors', id: '1', locale: true) }.to raise_error(ActionController::BadRequest, /locale/)
    end
  end

  describe '.from_legacy_hash' do
    it 'reads the permitted form params as ActiveJob deserializes them' do
      hash = {'kind' => 'all', 'locale' => 'ja', 'plan_id' => '12', 'status' => 'pending'}.with_indifferent_access

      expect(described_class.from_legacy_hash(hash)).to eq(
        filter_class.new(
          current_sponsors: filter_class::CurrentSponsors.new(locale: 'ja', plan_id: 12, status: :SPONSORSHIP_STATUS_PENDING),
        ),
      )
    end

    it 'returns nil for none' do
      expect(described_class.from_legacy_hash({'kind' => 'none'})).to be_nil
    end
  end
end
