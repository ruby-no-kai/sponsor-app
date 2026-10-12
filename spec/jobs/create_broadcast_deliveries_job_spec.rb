# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
RSpec.describe CreateBroadcastDeliveriesJob, type: :job do
  let!(:conference) { FactoryBot.create(:conference, :full) }
  let!(:broadcast) { FactoryBot.create(:broadcast, conference:) }

  describe 'filters' do
    subject(:sponsorships) { recipients.map(&:sponsorship).sort_by(&:id) }

    let(:plan_alpha) { FactoryBot.create(:plan, conference:, name: 'plan1') }
    let(:plan_beta) { FactoryBot.create(:plan, conference:, name: 'plan2') }

    let(:params) { {} }

    let(:recipients) { described_class.new(broadcast:, params:).recipients }

    describe CreateBroadcastDeliveriesJob::Filters::All do
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
        context "when all" do
          let(:params) { {status: 'all'} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:).order(id: :asc).to_a,
            )
          end
        end

        context "when active" do
          let(:params) { {status: 'active'} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, withdrawn_at: nil).where.not(accepted_at: nil).order(id: :asc).to_a,
            )
          end
        end

        context "when pending" do
          let(:params) { {status: 'pending'} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, accepted_at: nil, withdrawn_at: nil).order(id: :asc).to_a,
            )
          end
        end

        context "when accepted" do
          let(:params) { {status: 'accepted'} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:).accepted.order(id: :asc).to_a,
            )
          end
        end
      end

      describe "plan" do
        context "with plan1" do
          let(:params) { {plan_id: plan_alpha.id} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, plan: plan_alpha).order(id: :asc).to_a,
            )
          end
        end
      end

      describe "locale" do
        context "when ja" do
          let(:params) { {locale: 'ja'} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, locale: 'ja').order(id: :asc).to_a,
            )
          end
        end

        context "when en" do
          let(:params) { {locale: 'en'} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, locale: 'en').order(id: :asc).to_a,
            )
          end
        end
      end

      describe "exhibitor" do
        context "when yes" do
          let(:params) { {exhibitors: '1'} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:).exhibitor.order(id: :asc).to_a,
            )
          end
        end
      end

      describe "composite" do
        context "with ja pending plan" do
          let(:params) { {locale: 'ja', status: 'pending', plan_id: plan_alpha} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, plan: plan_alpha, accepted_at: nil, withdrawn_at: nil, locale: 'ja').order(id: :asc).to_a,
            )
          end
        end

        context "with ja active plan" do
          let(:params) { {locale: 'ja', status: 'active', plan_id: plan_beta} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, plan: plan_beta, locale: 'ja', withdrawn_at: nil).where.not(accepted_at: nil).order(id: :asc).to_a,
            )
          end
        end

        context "with ja accepted exhibitors" do
          let(:params) { {locale: 'ja', exhibitors: '1', status: 'accepted'} }

          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, locale: 'ja').accepted.exhibitor.order(id: :asc).to_a,
            )
          end
        end
      end
    end

    describe CreateBroadcastDeliveriesJob::Filters::Raw do
      let(:params) { {emails: "a@example.com\nb@example.com\n"} }

      it 'builds one recipient without a sponsorship per line' do
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

    it 'creates a ready delivery per recipient and marks the broadcast ready' do
      filters = [
        {kind: 'all'},
        {kind: 'raw', emails: "raw@example.com\n"},
      ].map(&:with_indifferent_access)
      described_class.perform_now(broadcast, filters)

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

      described_class.perform_now(broadcast, [{kind: 'raw', emails: "raw@example.com\n"}.with_indifferent_access])

      expect(broadcast.deliveries.pluck(:recipient)).to eq(['raw@example.com'])
    end
  end
end
# rubocop:enable RSpec/NestedGroups
