# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
RSpec.describe CreateBroadcastDeliveriesJob, type: :job do
  filter_class = Rk::SponsorApp::Internal::BroadcastRecipientFilter

  let!(:conference) { FactoryBot.create(:conference, :full) }
  let!(:broadcast) { FactoryBot.create(:broadcast, conference:) }

  describe 'filters' do
    subject(:sponsorships) { recipients.map(&:sponsorship).sort_by(&:id) }

    let(:plan_alpha) { FactoryBot.create(:plan, conference:, name: 'plan1') }
    let(:plan_beta) { FactoryBot.create(:plan, conference:, name: 'plan2') }

    let(:recipients) { described_class.new(broadcast:, filter:).recipients }

    describe CreateBroadcastDeliveriesJob::Filters::CurrentSponsors do
      let(:attributes) { {} }
      let(:filter) { filter_class::CurrentSponsors.new(**attributes) }

      before do
        %i(accepted pending withdrawn).each do |status|
          [plan_alpha, plan_beta].each do |plan|
            %w(en ja).each do |locale|
              [:booth, nil].each do |booth_status|
                2.times do |n|
                  FactoryBot.create(
                    :sponsorship,
                    conference:,
                    booth_assigned: !!booth_status,
                    name: [status, plan.name, locale, booth_status, n].join(' '),
                    locale:,
                    plan:,
                    accepted_at: status == :accepted ? Time.zone.now : nil,
                    withdrawn_at: status == :withdrawn ? Time.zone.now : nil,
                  )
                end
              end
            end
          end
        end
      end

      describe "status" do
        context "when unspecified" do
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:).order(id: :asc).to_a,
            )
          end
        end

        context "when active" do
          let(:attributes) { {status: :SPONSORSHIP_STATUS_ACTIVE} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, withdrawn_at: nil).where.not(accepted_at: nil).order(id: :asc).to_a,
            )
          end
        end

        context "when pending" do
          let(:attributes) { {status: :SPONSORSHIP_STATUS_PENDING} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, accepted_at: nil, withdrawn_at: nil).order(id: :asc).to_a,
            )
          end
        end

        context "when accepted" do
          let(:attributes) { {status: :SPONSORSHIP_STATUS_ACCEPTED} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:).accepted.order(id: :asc).to_a,
            )
          end
        end

        context "when not accepted" do
          let(:attributes) { {status: :SPONSORSHIP_STATUS_NOT_ACCEPTED} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, accepted_at: nil).order(id: :asc).to_a,
            )
          end
        end

        context "when withdrawn" do
          let(:attributes) { {status: :SPONSORSHIP_STATUS_WITHDRAWN} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:).withdrawn.order(id: :asc).to_a,
            )
          end
        end
      end

      describe "plan" do
        context "with plan1" do
          let(:attributes) { {plan_id: plan_alpha.id} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, plan: plan_alpha).order(id: :asc).to_a,
            )
          end
        end

        context "with a plan of another conference" do
          let(:attributes) { {plan_id: FactoryBot.create(:plan).id} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:).order(id: :asc).to_a,
            )
          end
        end
      end

      describe "locale" do
        context "when ja" do
          let(:attributes) { {locale: 'ja'} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, locale: 'ja').order(id: :asc).to_a,
            )
          end
        end

        context "when en" do
          let(:attributes) { {locale: 'en'} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, locale: 'en').order(id: :asc).to_a,
            )
          end
        end
      end

      describe "exhibitor" do
        context "when yes" do
          let(:attributes) { {exhibitors_only: true} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:).exhibitor.order(id: :asc).to_a,
            )
          end
        end
      end

      describe "composite" do
        context "with ja pending plan" do
          let(:attributes) { {locale: 'ja', status: :SPONSORSHIP_STATUS_PENDING, plan_id: plan_alpha.id} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, plan: plan_alpha, accepted_at: nil, withdrawn_at: nil, locale: 'ja').order(id: :asc).to_a,
            )
          end
        end

        context "with ja active plan" do
          let(:attributes) { {locale: 'ja', status: :SPONSORSHIP_STATUS_ACTIVE, plan_id: plan_beta.id} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, plan: plan_beta, locale: 'ja', withdrawn_at: nil).where.not(accepted_at: nil).order(id: :asc).to_a,
            )
          end
        end

        context "with ja accepted exhibitors" do
          let(:attributes) { {locale: 'ja', exhibitors_only: true, status: :SPONSORSHIP_STATUS_ACCEPTED} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, locale: 'ja').accepted.exhibitor.order(id: :asc).to_a,
            )
          end
        end
      end
    end

    describe CreateBroadcastDeliveriesJob::Filters::PastSponsors do
      let(:past_conference) { FactoryBot.create(:conference) }
      let(:attributes) { {} }
      let(:filter) { filter_class::PastSponsors.new(conference_id: past_conference.id, **attributes) }

      let!(:past_accepted) { FactoryBot.create(:sponsorship, conference: past_conference, plan: nil, locale: 'ja', accepted_at: Time.zone.now) }
      let!(:past_pending) { FactoryBot.create(:sponsorship, conference: past_conference, plan: nil, locale: 'en') }

      before do
        FactoryBot.create(:sponsorship, conference:)
      end

      it 'lists every sponsorship of the other conference' do
        expect(sponsorships).to eq([past_accepted, past_pending])
      end

      context "with a status" do
        let(:attributes) { {status: :SPONSORSHIP_STATUS_ACCEPTED} }

        specify { expect(sponsorships).to eq([past_accepted]) }
      end

      context "with a locale" do
        let(:attributes) { {locale: 'en'} }

        specify { expect(sponsorships).to eq([past_pending]) }
      end

      context "with exclude_current_sponsors" do
        let(:attributes) { {exclude_current_sponsors: true} }

        before do
          FactoryBot.create(:sponsorship, conference:).update!(organization: past_accepted.organization)
        end

        it 'keeps organizations that also sponsor the current conference' do
          expect(sponsorships).to eq([past_accepted, past_pending])
        end
      end

      context "with a missing conference" do
        let(:filter) { filter_class::PastSponsors.new(conference_id: 0) }

        specify { expect { recipients }.to raise_error(ActiveRecord::RecordNotFound) }
      end
    end

    describe CreateBroadcastDeliveriesJob::Filters::Manual do
      let(:picked) { FactoryBot.create_list(:sponsorship, 2, conference:) }
      let(:filter) { filter_class::Manual.new(sponsorship_ids: picked.map(&:id)) }

      before do
        FactoryBot.create(:sponsorship, conference:)
      end

      it 'lists the picked sponsorships' do
        expect(sponsorships).to eq(picked)
        expect(recipients.map(&:email)).to match_array(picked.map { it.contact.email })
      end
    end

    describe CreateBroadcastDeliveriesJob::Filters::Raw do
      let(:filter) { filter_class::Raw.new(emails: %w(a@example.com b@example.com)) }

      it 'builds one recipient without a sponsorship per email' do
        expect(recipients.map(&:email)).to eq(%w(a@example.com b@example.com))
        expect(recipients.map(&:sponsorship)).to eq([nil, nil])
        expect(recipients.map(&:email_ccs)).to eq([[], []])
      end
    end
  end

  describe '#perform' do
    let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }

    before do
      sponsorship.contact.update!(email_cc: 'cc@example.com')
    end

    def perform_through_queue(*arguments)
      job = described_class.new(*arguments)
      job.deserialize(JSON.parse(JSON.generate(job.serialize)))
      job.perform_now
    end

    it 'creates a ready delivery per recipient and marks the broadcast ready' do
      perform_through_queue(broadcast, [
        filter_class.new(current_sponsors: filter_class::CurrentSponsors.new),
        filter_class.new(raw: filter_class::Raw.new(emails: ['raw@example.com'])),
      ])

      deliveries = broadcast.deliveries.order(id: :asc).map { |d| [d.recipient, d.recipient_cc, d.sponsorship] }
      expect(deliveries).to eq([
        [sponsorship.contact.email, 'cc@example.com', sponsorship],
        ['raw@example.com', '', nil],
      ])
      expect(broadcast.reload).to be_ready
    end

    it 'skips recipients that already have a delivery' do
      FactoryBot.create(:broadcast_delivery, broadcast:, recipient: 'raw@example.com')
      broadcast.update!(status: :ready)

      perform_through_queue(broadcast, [filter_class.new(raw: filter_class::Raw.new(emails: ['raw@example.com']))])

      expect(broadcast.deliveries.pluck(:recipient)).to eq(['raw@example.com'])
    end

    it 'refuses a filter without a kind' do
      expect { described_class.perform_now(broadcast, [filter_class.new]) }.to raise_error(ArgumentError, /kind/)
      expect(broadcast.reload).to be_created
    end

    context "with the permitted form params as the argument" do
      it 'creates the deliveries the params select' do
        perform_through_queue(broadcast, [
          ActionController::Parameters.new(kind: 'all', locale: 'en', status: 'all').permit!,
          ActionController::Parameters.new(kind: 'raw', emails: "raw@example.com\n").permit!,
        ])

        deliveries = broadcast.deliveries.order(id: :asc).map { |d| [d.recipient, d.sponsorship] }
        expect(deliveries).to eq([
          [sponsorship.contact.email, sponsorship],
          ['raw@example.com', nil],
        ])
        expect(broadcast.reload).to be_ready
      end

      it 'creates no deliveries for none' do
        perform_through_queue(broadcast, [ActionController::Parameters.new(kind: 'none').permit!])

        expect(broadcast.deliveries).to be_empty
        expect(broadcast.reload).to be_ready
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
