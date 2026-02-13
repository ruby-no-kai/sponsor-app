require 'rails_helper'

RSpec.describe GenerateSponsorsYamlFileJob, '#events_data and #yaml_data' do
  let(:conference) { FactoryBot.create(:conference, :full) }

  def run_job
    job = described_class.new
    job.perform(conference, push: false)
    job
  end

  describe '#events_data' do
    let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, accepted_at: Time.current) }

    it 'excludes withdrawn primary sponsorship from hosts' do
      sponsorship.update!(withdrawn_at: Time.current)
      FactoryBot.create(:sponsor_event, :accepted, sponsorship:)

      job = run_job
      hosts = job.events_data.first&.dig(:hosts) || []
      expect(hosts).to be_empty
    end

    it 'includes non-withdrawn primary sponsorship in hosts' do
      FactoryBot.create(:sponsor_event, :accepted, sponsorship:)

      job = run_job
      hosts = job.events_data.first.fetch(:hosts)
      expect(hosts.map { |h| h[:slug] }).to include(sponsorship.slug)
    end

    it 'excludes withdrawn co-host from hosts' do
      co_host = FactoryBot.create(:sponsorship, conference:, accepted_at: Time.current)
      co_host.update!(withdrawn_at: Time.current)
      FactoryBot.create(:sponsor_event, :accepted, sponsorship:, co_host_sponsorship_ids: [co_host.id])

      job = run_job
      hosts = job.events_data.first.fetch(:hosts)
      slugs = hosts.map { |h| h[:slug] }
      expect(slugs).to include(sponsorship.slug)
      expect(slugs).not_to include(co_host.slug)
    end
  end

  describe '#yaml_data' do
    it 'generates YAML with events when no sponsorships have presence' do
      sponsorship = FactoryBot.create(:sponsorship, conference:, accepted_at: Time.current)
      FactoryBot.create(:sponsor_event, :accepted, sponsorship:)
      # Withdraw sponsorship so have_presence returns nothing
      sponsorship.update!(withdrawn_at: Time.current)

      job = run_job
      expect(job.yaml_data).not_to be_nil
      parsed = YAML.safe_load(job.yaml_data, permitted_classes: [Time, Date, DateTime, Symbol])
      expect(parsed).to have_key('_events')
      expect(parsed['_events'].length).to eq(1)
    end

    it 'returns nil when no sponsorships and no accepted events exist' do
      job = run_job
      expect(job.yaml_data).to be_nil
    end

    it 'includes events alongside sponsorship data' do
      sponsorship = FactoryBot.create(:sponsorship, conference:, accepted_at: Time.current)
      FactoryBot.create(:sponsor_event, :accepted, sponsorship:)

      job = run_job
      expect(job.yaml_data).not_to be_nil
      parsed = YAML.safe_load(job.yaml_data, permitted_classes: [Time, Date, DateTime, Symbol])
      expect(parsed).to have_key('_events')
    end
  end
end
