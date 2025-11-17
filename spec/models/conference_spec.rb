require 'rails_helper'

RSpec.describe Conference, type: :model do

  describe 'associations' do

    it 'has many plans' do
      expect(Conference.reflect_on_association(:plans).macro).to eq(:has_many)
      expect(Conference.reflect_on_association(:plans).options[:dependent]).to eq(:destroy)
    end





    it 'orders plans by rank ascending' do
      conference = FactoryBot.create(:conference)
      plan1 = FactoryBot.create(:plan, conference:, rank: 2)
      plan2 = FactoryBot.create(:plan, conference:, rank: 1)
      plan3 = FactoryBot.create(:plan, conference:, rank: 3)

      expect(conference.plans.to_a).to eq([plan2, plan1, plan3])
    end
  end

  describe 'validations' do


    it 'auto-generates slug from name' do
      conference = FactoryBot.build(:conference, name: 'RubyKaigi 2025', slug: nil)
      conference.valid?
      expect(conference.slug).to eq('rubykaigi2025')
    end

    it 'requires unique slug' do
      existing = FactoryBot.create(:conference)
      duplicate = FactoryBot.build(:conference, slug: existing.slug)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include('has already been taken')
    end


    describe 'tito_slug format validation' do
      it 'accepts valid format' do
        conference = FactoryBot.build(:conference, tito_slug: 'rubykaigi/rubykaigi-2025')
        expect(conference).to be_valid
      end

      it 'accepts blank tito_slug' do
        conference = FactoryBot.build(:conference, tito_slug: '')
        expect(conference).to be_valid
      end

      it 'rejects invalid format without slash' do
        conference = FactoryBot.build(:conference, tito_slug: 'rubykaigi')
        expect(conference).not_to be_valid
        expect(conference.errors[:tito_slug]).to include('must be :account_slug/:event_slug')
      end

      it 'rejects invalid format with multiple slashes' do
        conference = FactoryBot.build(:conference, tito_slug: 'ruby/kaigi/2025')
        expect(conference).not_to be_valid
      end
    end

    describe 'github_repo validation' do
      it 'accepts valid github_repo with branch and path' do
        conference = FactoryBot.build(:conference, github_repo: 'owner/repo@main:data/sponsors.yml')
        expect(conference).to be_valid
      end

      it 'accepts valid github_repo without branch' do
        conference = FactoryBot.build(:conference, github_repo: 'owner/repo:data/sponsors.yml')
        expect(conference).to be_valid
      end

      it 'accepts blank github_repo' do
        conference = FactoryBot.build(:conference)
        expect(conference).to be_valid
      end

      it 'rejects github_repo without path' do
        conference = FactoryBot.build(:conference, github_repo: 'owner/repo@main')
        expect(conference).not_to be_valid
        expect(conference.errors[:github_repo]).to include('is invalid')
      end

      it 'rejects github_repo without name' do
        conference = FactoryBot.build(:conference, github_repo: ':data/sponsors.yml')
        expect(conference).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:open_conference) do
      FactoryBot.create(:conference,
        application_opens_at: 1.day.ago,
        application_closes_at: 1.day.from_now
      )
    end

    let!(:closed_conference) do
      FactoryBot.create(:conference,
        application_opens_at: 2.days.ago,
        application_closes_at: 1.day.ago
      )
    end

    let!(:not_yet_open_conference) do
      FactoryBot.create(:conference,
        application_opens_at: 1.day.from_now
      )
    end

    let!(:open_no_close_date) do
      FactoryBot.create(:conference,
        application_opens_at: 1.day.ago,
        application_closes_at: nil
      )
    end

    describe '.application_open' do
      it 'includes conferences with open applications' do
        expect(Conference.application_open).to include(open_conference)
      end

      it 'includes conferences with no close date' do
        expect(Conference.application_open).to include(open_no_close_date)
      end

      it 'excludes conferences with closed applications' do
        expect(Conference.application_open).not_to include(closed_conference)
      end

      it 'excludes conferences not yet open' do
        expect(Conference.application_open).not_to include(not_yet_open_conference)
      end
    end

    describe '.amendment_open' do
      let!(:amendment_open_conference) do
        FactoryBot.create(:conference,
          name: 'Amendment Open',
          slug: 'amendment-2025',
          contact_email_address: 'amendment@example.com',
          application_opens_at: 2.days.ago,
          amendment_closes_at: 1.day.from_now
        )
      end

      let!(:amendment_closed_conference) do
        FactoryBot.create(:conference,
          name: 'Amendment Closed',
          slug: 'amendment-closed-2024',
          contact_email_address: 'closed-amendment@example.com',
          application_opens_at: 3.days.ago,
          amendment_closes_at: 1.day.ago
        )
      end

      it 'includes conferences with open amendments' do
        expect(Conference.amendment_open).to include(amendment_open_conference)
      end

      it 'excludes conferences with closed amendments' do
        expect(Conference.amendment_open).not_to include(amendment_closed_conference)
      end
    end

    describe '.publicly_visible' do
      let!(:visible_conference) do
        FactoryBot.create(:conference,
          name: 'Visible',
          slug: 'visible',
          contact_email_address: 'visible@example.com',
          hidden: false
        )
      end

      let!(:hidden_conference) do
        FactoryBot.create(:conference,
          name: 'Hidden',
          slug: 'hidden',
          contact_email_address: 'hidden@example.com',
          hidden: true
        )
      end

      it 'includes non-hidden conferences' do
        expect(Conference.publicly_visible).to include(visible_conference)
      end

      it 'excludes hidden conferences' do
        expect(Conference.publicly_visible).not_to include(hidden_conference)
      end
    end
  end

  describe 'callbacks' do
    describe '#generate_slug' do
      it 'generates slug from name when slug is blank' do
        conference = FactoryBot.build(:conference, name: 'RubyKaigi 2025', slug: nil)
        conference.valid?
        expect(conference.slug).to eq('rubykaigi2025')
      end

      it 'does not overwrite existing slug' do
        conference = FactoryBot.build(:conference, name: 'RubyKaigi 2025', slug: 'custom-slug')
        conference.valid?
        expect(conference.slug).to eq('custom-slug')
      end

      it 'parameterizes the name' do
        conference = FactoryBot.build(:conference, name: 'Ruby Kaigi 2025!', slug: nil)
        conference.valid?
        expect(conference.slug).to match(/^ruby-?kaigi-?2025/)
      end
    end

    describe '#generate_reception_key' do
      it 'generates reception_key when not present' do
        conference = FactoryBot.create(:conference)
        expect(conference.reception_key).to be_present
        expect(conference.reception_key.length).to be > 50
      end

      it 'does not overwrite existing reception_key' do
        conference = FactoryBot.create(:conference, reception_key: 'existing-key')
        expect(conference.reception_key).to eq('existing-key')
      end
    end

    describe '#generate_invite_code' do
      it 'generates invite_code for hidden conferences' do
        conference = FactoryBot.create(:conference, hidden: true)
        expect(conference.invite_code).to be_present
        expect(conference.invite_code.length).to be > 30
      end

      it 'does not generate invite_code for visible conferences' do
        conference = FactoryBot.create(:conference, hidden: false)
        expect(conference.invite_code).to be_nil
      end

      it 'does not overwrite existing invite_code' do
        conference = FactoryBot.create(:conference, hidden: true, invite_code: 'existing-code')
        expect(conference.invite_code).to eq('existing-code')
      end
    end
  end

  describe '#to_param' do
    it 'returns slug' do
      conference = FactoryBot.build_stubbed(:conference)
      expect(conference.to_param).to eq(conference.slug)
    end
  end

  describe '#application_open?' do
    it 'returns true when currently open' do
      conference = FactoryBot.build_stubbed(:conference,
        application_opens_at: 1.day.ago,
        application_closes_at: 1.day.from_now
      )
      expect(conference.application_open?).to be true
    end

    it 'returns true when open with no close date' do
      conference = FactoryBot.build_stubbed(:conference,
        application_opens_at: 1.day.ago,
        application_closes_at: nil
      )
      expect(conference.application_open?).to be true
    end

    it 'returns false when closed' do
      conference = FactoryBot.build_stubbed(:conference,
        application_opens_at: 2.days.ago,
        application_closes_at: 1.day.ago
      )
      expect(conference.application_open?).to be false
    end

    it 'returns false when not yet open' do
      conference = FactoryBot.build_stubbed(:conference,
        application_opens_at: 1.day.from_now
      )
      expect(conference.application_open?).to be false
    end

    it 'returns nil when application_opens_at is nil' do
      conference = FactoryBot.build_stubbed(:conference)
      expect(conference.application_open?).to be_nil
    end
  end

  describe '#amendment_open?' do
    it 'returns true when currently open' do
      conference = FactoryBot.build_stubbed(:conference,
        application_opens_at: 1.day.ago,
        amendment_closes_at: 1.day.from_now
      )
      expect(conference.amendment_open?).to be true
    end

    it 'returns true when open with no close date' do
      conference = FactoryBot.build_stubbed(:conference,
        application_opens_at: 1.day.ago,
        amendment_closes_at: nil
      )
      expect(conference.amendment_open?).to be true
    end

    it 'returns false when closed' do
      conference = FactoryBot.build_stubbed(:conference,
        application_opens_at: 2.days.ago,
        amendment_closes_at: 1.day.ago
      )
      expect(conference.amendment_open?).to be false
    end
  end

  describe '#distributing_ticket?' do
    it 'returns true when distribution has started' do
      conference = FactoryBot.build_stubbed(:conference,
        ticket_distribution_starts_at: 1.day.ago
      )
      expect(conference.distributing_ticket?).to be true
    end

    it 'returns false when distribution has not started' do
      conference = FactoryBot.build_stubbed(:conference,
        ticket_distribution_starts_at: 1.day.from_now
      )
      expect(conference.distributing_ticket?).to be false
    end

    it 'returns nil when ticket_distribution_starts_at is nil' do
      conference = FactoryBot.build_stubbed(:conference)
      expect(conference.distributing_ticket?).to be_nil
    end
  end

  describe '#form_description_for_locale' do
    let(:conference) { FactoryBot.create(:conference) }

    it 'returns form description for current locale' do
      I18n.with_locale(:ja) do
        ja_desc = FactoryBot.create(:form_description, conference:, locale: 'ja')
        expect(conference.form_description_for_locale).to eq(ja_desc)
      end
    end

    it 'falls back to English when current locale not found' do
      en_desc = FactoryBot.create(:form_description, conference:, locale: 'en')
      I18n.with_locale(:ja) do
        expect(conference.form_description_for_locale).to eq(en_desc)
      end
    end

    it 'raises error when English locale not found' do
      I18n.with_locale(:ja) do
        expect {
          conference.form_description_for_locale
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#github_repo' do
    it 'parses full format with branch and path' do
      conference = FactoryBot.build_stubbed(:conference, github_repo: 'ruby-no-kai/sponsor-app@master:data/sponsors.yml')
      repo = conference.github_repo

      expect(repo).to be_a(Conference::GithubRepo)
      expect(repo.name).to eq('ruby-no-kai/sponsor-app')
      expect(repo.branch).to eq('master')
      expect(repo.path).to eq('data/sponsors.yml')
      expect(repo.raw).to eq('ruby-no-kai/sponsor-app@master:data/sponsors.yml')
    end

    it 'parses format without branch' do
      conference = FactoryBot.build_stubbed(:conference, github_repo: 'ruby-no-kai/sponsor-app:data/sponsors.yml')
      repo = conference.github_repo

      expect(repo.name).to eq('ruby-no-kai/sponsor-app')
      expect(repo.branch).to be_nil
      expect(repo.path).to eq('data/sponsors.yml')
    end

    it 'parses format with deep path' do
      conference = FactoryBot.build_stubbed(:conference, github_repo: 'owner/repo@main:data/2025/sponsors.yml')
      repo = conference.github_repo

      expect(repo.path).to eq('data/2025/sponsors.yml')
    end

    it 'returns nil when github_repo is blank' do
      conference = FactoryBot.build_stubbed(:conference)
      expect(conference.github_repo).to be_nil
    end

    it 'memoizes the result' do
      conference = FactoryBot.build_stubbed(:conference, github_repo: 'owner/repo:path')
      first_call = conference.github_repo
      second_call = conference.github_repo

      expect(first_call.object_id).to eq(second_call.object_id)
    end

    it 'recomputes when value changes' do
      conference = FactoryBot.create(:conference, github_repo: 'owner/repo1:path')
      first_repo = conference.github_repo

      conference.update!(github_repo: 'owner/repo2:path')
      second_repo = conference.github_repo

      expect(second_repo.name).to eq('owner/repo2')
      expect(first_repo.name).to eq('owner/repo1')
    end

    it 'converts to string with to_s' do
      conference = FactoryBot.build_stubbed(:conference, github_repo: 'owner/repo@main:path')
      expect(conference.github_repo.to_s).to eq('owner/repo@main:path')
    end
  end

  describe '#verify_invite_code' do
    context 'for visible conferences' do
      let(:conference) { FactoryBot.create(:conference, hidden: false) }

      it 'returns true for any code' do
        expect(conference.verify_invite_code('any-code')).to be true
      end

      it 'returns true for blank code' do
        expect(conference.verify_invite_code('')).to be true
      end
    end

    context 'for hidden conferences' do
      let(:conference) { FactoryBot.create(:conference, hidden: true) }

      it 'returns true for correct invite code' do
        expect(conference.verify_invite_code(conference.invite_code)).to be true
      end

      it 'returns false for incorrect invite code' do
        expect(conference.verify_invite_code('wrong-code')).to be false
      end

      it 'returns false for blank code' do
        expect(conference.verify_invite_code('')).to be false
      end

      it 'returns false for nil code' do
        expect(conference.verify_invite_code(nil)).to be false
      end

    end
  end
end
