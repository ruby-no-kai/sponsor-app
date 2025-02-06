require 'rails_helper'

RSpec.describe CreateBroadcastDeliveriesJob, type: :job do
  let!(:conference) { FactoryBot.create(:conference, :full) }
  let!(:broadcast) { FactoryBot.create(:broadcast, conference:) }

  describe 'filters' do
    let!(:plan1) { FactoryBot.create(:plan, conference:, name: 'plan1') }
    let!(:plan2) { FactoryBot.create(:plan, conference:, name: 'plan2') }

    let(:params) { {} }
    subject(:recipients) { described_class.new(broadcast:, params:).recipients }
    subject(:sponsorships) { recipients.map(&:sponsorship).sort_by(&:id) }

    describe CreateBroadcastDeliveriesJob::Filters::All do
      before do
        %i(accepted pending withdrawn).each do |status|
          [plan1,plan2].each do |plan|
            %w(en ja).each do |locale|
              [:booth, nil].each do |booth_status|
                2.times do |n|
                  FactoryBot.create(
                    :sponsorship,
                    conference:,
                    booth_assigned: !!booth_status,
                    name: [status,plan.name,locale,booth_status,n].map(&:to_s).join(' '),
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
        context "all" do
          let(:params) { {status: 'all'} }
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:).order(id: :asc).to_a
            )
          end
        end

        context "not_accepted" do
          let(:params) { {status: 'not_accepted'} }
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, accepted_at: nil).order(id: :asc).to_a
            )
          end
        end

        context "pending" do
          let(:params) { {status: 'pending'} }
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, accepted_at: nil, withdrawn_at: nil).order(id: :asc).to_a
            )
          end
        end

        context "accepted" do
          let(:params) { {status: 'accepted'} }
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:).accepted.order(id: :asc).to_a
            )
          end
        end
      end

      describe "plan" do
        context "plan1" do
          let(:params) { {plan_id: plan1.id} }
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, plan: plan1).order(id: :asc).to_a
            )
          end
        end
      end

      describe "locale" do
        context "ja" do
          let(:params) { {locale: 'ja'} }
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, locale: 'ja').order(id: :asc).to_a
            )
          end
        end

        context "en" do
          let(:params) { {locale: 'en'} }
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, locale: 'en').order(id: :asc).to_a
            )
          end
        end
      end

      describe "exhibitor" do
        context "yes" do
          let(:params) { {exhibitors: '1'} }
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:).exhibitor.order(id: :asc).to_a
            )
          end
        end
      end

      describe "composite" do
        context "ja not_accepted plan" do
          let(:params) { {locale: 'ja', status: 'not_accepted', plan_id: plan1} }
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, plan: plan1, accepted_at: nil, locale: 'ja').order(id: :asc).to_a
            )
          end
        end

        context "ja accepted plan" do
          let(:params) { {locale: 'ja', status: 'accepted', plan_id: plan2} }
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, plan: plan2, locale: 'ja').accepted.order(id: :asc).to_a
            )
          end
        end

        context "ja accepted exhibitors" do
          let(:params) { {locale: 'ja', exhibitors: '1', status: 'accepted'} }
          specify do
            expect(sponsorships).to eq(
              Sponsorship.where(conference:, locale: 'ja').accepted.exhibitor.order(id: :asc).to_a
            )
          end
        end
      end
    end
  end
end
