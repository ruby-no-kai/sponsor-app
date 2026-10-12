# frozen_string_literal: true

require 'rails_helper'

# The conference website reads these documents, so their bytes are pinned by the golden files.
RSpec.describe GenerateSponsorsYamlFileJob, '#yaml_data and #json_data' do
  let(:conference) { FactoryBot.create(:conference) }
  let(:ruby_plan) { FactoryBot.create(:plan, conference:, name: 'Ruby', rank: 1) }
  let(:platinum_plan) { FactoryBot.create(:plan, conference:, name: 'Platinum', rank: 2) }
  let(:gold_plan) { FactoryBot.create(:plan, conference:, name: 'Gold Sponsor', rank: 3) }

  def golden(name)
    file_fixture("sponsors_yaml/#{name}").read
  end

  # Fixed ids, as they appear in the golden files.
  def create_sponsorship(id:, domain:, **attributes)
    sponsorship = FactoryBot.build(
      :sponsorship,
      id:,
      conference:,
      name: "#{domain.split('.').fetch(0).capitalize} Inc.",
      url: "https://#{domain}/",
      profile: "We are #{domain}.",
      accepted_at: Time.utc(2026, 4, 1, 9, 0, 0),
      asset_file: FactoryBot.create(:sponsorship_asset_file, id: id + 100),
      **attributes,
    )
    sponsorship.organization = FactoryBot.create(:organization, name: domain, domain:)
    sponsorship.tap(&:save!)
  end

  def create_event(id:, sponsorship:, **attributes)
    FactoryBot.create(:sponsor_event, :accepted, id:, sponsorship:, url: "https://events.invalid/#{id}", **attributes)
  end

  # The YAML header carries the latest editing history ids.
  def pin_history_ids
    SponsorshipEditingHistory.order(:id).each.with_index(1_000_500) { |history, id| history.update!(id:) }
    SponsorEventEditingHistory.order(:id).each.with_index(1_000_600) { |history, id| history.update!(id:) }
  end

  def run_job
    described_class.new.tap { |job| job.perform(conference, push: false) }
  end

  context 'with sponsors and events' do
    before do
      fabrikam = create_sponsorship(
        id: 1_000_010,
        domain: 'fabrikam.invalid',
        plan: platinum_plan,
        url: "https://fabrikam.invalid/  \n",
        profile: "Fabrikam builds things.\n\nWe: love \"Ruby\" & YAML!",
      )
      contoso = create_sponsorship(id: 1_000_011, domain: 'contoso.invalid', plan: ruby_plan)
      lounge = create_sponsorship(
        id: 1_000_012,
        domain: 'lounge.invalid',
        plan: platinum_plan,
        customization: true,
        customization_name: 'Platinum Lounge',
      )
      planned = create_sponsorship(
        id: 1_000_013,
        domain: 'planned.invalid',
        plan: gold_plan,
        customization: false,
        customization_name: 'Gold Cafe',
      )
      no_asset = create_sponsorship(id: 1_000_014, domain: 'noasset.invalid', plan: platinum_plan)
      no_asset.asset_file.delete

      create_sponsorship(id: 1_000_015, domain: 'suspended.invalid', plan: ruby_plan, suspended: true)
      create_sponsorship(id: 1_000_016, domain: 'pending.invalid', plan: ruby_plan, accepted_at: nil)
      withdrawn = create_sponsorship(id: 1_000_017, domain: 'withdrawn.invalid', plan: gold_plan)
      create_sponsorship(id: 1_000_018, domain: 'noplan.invalid', plan: nil)

      create_event(
        id: 1_000_050,
        sponsorship: contoso,
        slug: 'contoso-drinkup',
        title: 'Contoso Drinkup',
        starts_at: Time.utc(2026, 5, 11, 18, 30, 0),
        co_host_sponsorship_ids: [withdrawn.id, planned.id, fabrikam.id],
        price: 'Free',
        capacity: '100 people',
        location_en: 'Tokyo',
        location_local: '東京',
        link_name: 'Drinkup',
      )
      create_event(
        id: 1_000_051,
        sponsorship: lounge,
        slug: 'lounge-meetup',
        title: 'Lounge Meetup',
        starts_at: Time.utc(2026, 5, 10, 12, 0, 0),
      )
      create_event(id: 1_000_052, sponsorship: contoso, slug: 'contoso-pending', title: 'Pending', status: :pending, starts_at: Time.utc(2026, 5, 9))

      withdrawn.update!(withdrawn_at: Time.utc(2026, 4, 2, 9, 0, 0))
      pin_history_ids
    end

    it 'writes the sponsors YAML' do
      expect(run_job.yaml_data).to eq(golden('sponsors.yml'))
    end

    it 'writes the sponsors JSON' do
      expect(run_job.json_data).to eq(golden('sponsors.json'))
    end
  end

  context 'with events only' do
    before do
      sponsorship = create_sponsorship(id: 1_000_020, domain: 'contoso.invalid', plan: ruby_plan)
      create_event(id: 1_000_060, sponsorship:, slug: 'contoso-drinkup', title: 'Contoso Drinkup', starts_at: Time.utc(2026, 5, 11, 18, 30, 0))
      sponsorship.update!(suspended: true)
      pin_history_ids
    end

    it 'writes the events YAML' do
      expect(run_job.yaml_data).to eq(golden('events_only.yml'))
    end

    it 'writes no sponsors JSON' do
      expect(run_job.json_data).to be_nil
    end
  end
end
