# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BoothAssignment, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:, booth_size: 2) }
  let(:staff) { FactoryBot.create(:staff) }
  let!(:first) { FactoryBot.create(:sponsorship, conference:, plan:, booth_requested: true, accepted_at: Time.current) }
  let!(:second) { FactoryBot.create(:sponsorship, conference:, plan:, booth_requested: true, accepted_at: Time.current) }
  let(:booth_assignment) { described_class.new(conference) }

  before do
    allow(ProcessSponsorshipEditJob).to receive(:perform_later)
  end

  describe '#assign!' do
    it 'refreshes the candidates it read before assigning' do
      expect(booth_assignment.assigned_count).to eq(0)

      booth_assignment.assign!([first.id], staff:)

      expect(booth_assignment).to have_attributes(assigned_count: 1, assigned_booth_size: 2)
    end

    it 'raises with the IDs the conference does not have, changing nothing' do
      other = FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference), plan: nil)

      expect { booth_assignment.assign!([first.id, other.id], staff:) }
        .to raise_error(described_class::UnknownSponsorships) { expect(it.ids).to eq([other.id]) }
      expect(first.reload.booth_assigned).to be(false)
    end

    it 'raises with the IDs that would give a booth to a sponsorship not active, changing nothing' do
      withdrawn = FactoryBot.create(:sponsorship, conference:, plan:, accepted_at: Time.current, withdrawn_at: Time.current)
      pending = FactoryBot.create(:sponsorship, conference:, plan:)

      expect { booth_assignment.assign!([first.id, pending.id, withdrawn.id], staff:) }
        .to raise_error(described_class::InactiveSponsorships) { expect(it.ids).to eq([withdrawn.id, pending.id]) }
      expect(first.reload.booth_assigned).to be(false)
    end

    it 'lets a sponsorship not active keep the booth it holds' do
      pending = FactoryBot.create(:sponsorship, conference:, plan:, booth_assigned: true)

      booth_assignment.assign!([first.id, pending.id], staff:)

      expect([first.reload.booth_assigned, pending.reload.booth_assigned]).to eq([true, true])
    end

    it 'changes and publishes nothing when a save fails midway' do
      saves = 0
      allow_any_instance_of(Sponsorship).to receive(:save!).and_wrap_original do |save, *args, **kwargs| # rubocop:disable RSpec/AnyInstance
        saves += 1
        raise ActiveRecord::StatementInvalid, 'connection lost' if saves == 2

        save.call(*args, **kwargs)
      end

      expect { booth_assignment.assign!([first.id, second.id], staff:) }.to raise_error(ActiveRecord::StatementInvalid)
      expect([first.reload.booth_assigned, second.reload.booth_assigned]).to eq([false, false])
      expect(first.editing_histories.where(staff:)).to be_empty
      expect(ProcessSponsorshipEditJob).not_to have_received(:perform_later)
    end
  end
end
