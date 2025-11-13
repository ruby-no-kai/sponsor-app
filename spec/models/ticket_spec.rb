require 'rails_helper'

RSpec.describe Ticket, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:, number_of_guests: 3, booth_size: 6) }
  let(:sponsorship) do
    sponsorship = FactoryBot.create(:sponsorship, plan:, conference:)
    sponsorship.update!(accepted_at: Time.current, booth_assigned: true)
    sponsorship
  end

  describe 'scopes' do
    let!(:checked_in_ticket) { FactoryBot.create(:ticket, :checked_in, conference:, sponsorship:) }
    let!(:unused_ticket) { FactoryBot.create(:ticket, conference:, sponsorship:) }

    describe '.checked_in' do
      it 'includes tickets with checked_in_at set' do
        expect(Ticket.checked_in).to include(checked_in_ticket)
      end

      it 'excludes tickets without checked_in_at' do
        expect(Ticket.checked_in).not_to include(unused_ticket)
      end
    end

    describe '.unused' do
      it 'includes tickets without checked_in_at' do
        expect(Ticket.unused).to include(unused_ticket)
      end

      it 'excludes tickets with checked_in_at set' do
        expect(Ticket.unused).not_to include(checked_in_ticket)
      end
    end
  end

  describe 'validations' do


    it 'auto-generates code when not provided' do
      ticket = FactoryBot.build(:ticket, conference:, sponsorship:)
      ticket.code = nil
      ticket.valid?
      expect(ticket.code).not_to be_nil
    end


    describe '#validate_correct_sponsorship' do
      it 'validates sponsorship belongs to same conference' do
        other_conference = FactoryBot.create(:conference)
        ticket = FactoryBot.build(:ticket, sponsorship:, conference: other_conference)
        expect(ticket).not_to be_valid
        expect(ticket.errors[:plan]).to include("can't belong to a sponsorship for an another conference")
      end

      it 'is valid when sponsorship and conference match' do
        ticket = FactoryBot.build(:ticket, conference:, sponsorship:)
        expect(ticket).to be_valid
      end
    end

    describe '#deny_multiple_entry' do
      it 'prevents checking in an already checked-in ticket' do
        ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
        ticket.update!(checked_in_at: Time.current)

        ticket.checked_in_at = 1.hour.from_now
        expect(ticket).not_to be_valid
        expect(ticket.errors[:base]).to include('already checked in')
      end

      it 'allows checking in a new ticket' do
        ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
        ticket.checked_in_at = Time.current
        expect(ticket).to be_valid
      end
    end

    describe '#check_availability' do
      it 'prevents checking in when attendee tickets are at capacity' do
        # Plan has 3 guest slots, create 3 checked-in tickets
        3.times do |i|
          FactoryBot.create(:ticket, :checked_in, conference:, sponsorship:, name: "Attendee #{i}")
        end

        # Try to check in a 4th ticket
        extra_ticket = FactoryBot.create(:ticket, conference:, sponsorship:, name: 'Extra')
        extra_ticket.checked_in_at = Time.current
        expect(extra_ticket).not_to be_valid
        expect(extra_ticket.errors[:base]).to include('ticket is out of stock')
      end

      it 'allows checking in when under capacity' do
        # Create but don't check in
        FactoryBot.create(:ticket, conference:, sponsorship:)

        # This one should be allowed
        ticket = FactoryBot.create(:ticket, conference:, sponsorship:, name: 'New')
        ticket.checked_in_at = Time.current
        expect(ticket).to be_valid
      end

      it 'validates booth_staff tickets separately' do
        # Check in 3 attendee tickets
        3.times do |i|
          FactoryBot.create(:ticket, :checked_in, conference:, sponsorship:, name: "Attendee #{i}")
        end

        # Booth staff ticket should still be allowed (different kind)
        booth_ticket = FactoryBot.create(:ticket, conference:, sponsorship:, kind: :booth_staff, name: 'Booth Staff')
        booth_ticket.checked_in_at = Time.current
        expect(booth_ticket).to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe '#assume_conference' do
      it 'sets conference from sponsorship when not provided' do
        ticket = FactoryBot.build(:ticket, sponsorship:, conference: nil)
        ticket.valid?
        expect(ticket.conference).to eq(conference)
      end

      it 'does not overwrite explicit conference' do
        other_conference = FactoryBot.create(:conference)
        ticket = FactoryBot.build(:ticket, sponsorship:, conference: other_conference)
        ticket.valid?
        expect(ticket.conference).to eq(other_conference)
      end
    end

    describe '#generate_code' do
      it 'generates code when not provided' do
        ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
        expect(ticket.code).to be_present
        expect(ticket.code.length).to eq(8)
      end

      it 'uses allowed characters only' do
        ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
        ticket.code.each_char do |char|
          expect(Ticket::CODE_CHARS).to include(char)
        end
      end

      it 'does not overwrite explicit code' do
        ticket = FactoryBot.build(:ticket, conference:, sponsorship:, code: 'TESTCODE')
        ticket.save!
        expect(ticket.code).to eq('TESTCODE')
      end

      it 'generates unique codes' do
        codes = 10.times.map do
          FactoryBot.create(:ticket, conference:, sponsorship:, name: "Ticket #{_1}").code
        end
        expect(codes.uniq.length).to eq(10)
      end
    end

    describe '#generate_handle' do
      it 'generates handle when not provided' do
        ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
        expect(ticket.handle).to be_present
        expect(ticket.handle.length).to be > 50
      end

      it 'does not overwrite explicit handle' do
        ticket = FactoryBot.build(:ticket, conference:, sponsorship:, handle: 'test-handle')
        ticket.save!
        expect(ticket.handle).to eq('test-handle')
      end

      it 'generates unique handles' do
        handles = 10.times.map do
          FactoryBot.create(:ticket, conference:, sponsorship:, name: "Ticket #{_1}").handle
        end
        expect(handles.uniq.length).to eq(10)
      end
    end
  end

  describe '#to_param' do
    it 'returns conference_id-code format' do
      ticket = FactoryBot.build_stubbed(:ticket, conference:, sponsorship:)
      expect(ticket.to_param).to eq("#{conference.id}-#{ticket.code}")
    end
  end

  describe '#as_json' do
    it 'returns formatted hash' do
      ticket = FactoryBot.build_stubbed(:ticket, conference:, sponsorship:, kind: :attendee)
      json = ticket.as_json

      expect(json[:id]).to eq(ticket.id)
      expect(json[:code]).to eq(ticket.code)
      expect(json[:kind]).to eq('attendee')
      expect(json[:name]).to be_present
      expect(json[:sponsor]).to eq(sponsorship.name)
      expect(json[:conference]).to eq(conference.name)
    end

    it 'includes sponsor name' do
      ticket = FactoryBot.build_stubbed(:ticket, conference:, sponsorship:)
      json = ticket.as_json
      expect(json[:sponsor]).to eq(sponsorship.name)
    end
  end

  describe '#checked_in?' do
    it 'returns false when checked_in_at is nil' do
      ticket = FactoryBot.build_stubbed(:ticket, conference:, sponsorship:)
      expect(ticket.checked_in?).to be false
    end

    it 'returns true when checked_in_at is set' do
      ticket = FactoryBot.build_stubbed(:ticket, :checked_in, conference:, sponsorship:)
      expect(ticket.checked_in?).to be true
    end
  end

  describe '#do_check_in' do
    it 'sets checked_in_at to current time' do
      ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
      before_time = Time.current
      ticket.do_check_in
      after_time = Time.current
      expect(ticket.checked_in_at).to be_between(before_time, after_time)
    end

    it 'sets authorized flag' do
      ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
      ticket.do_check_in(authorized: true)
      expect(ticket.authorized).to be true
    end

    it 'defaults authorized to false' do
      ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
      ticket.do_check_in
      expect(ticket.authorized).to be false
    end

    it 'does not save the record' do
      ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
      ticket.do_check_in
      ticket.reload
      expect(ticket.checked_in_at).to be_nil
    end
  end

  describe '#check_in' do
    it 'checks in and saves the ticket' do
      ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
      result = ticket.check_in
      expect(result).to be true
      ticket.reload
      expect(ticket.checked_in_at).to be_present
    end

    it 'returns false if save fails' do
      ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
      ticket.update!(checked_in_at: 1.hour.ago)

      # Try to check in again (should fail validation)
      result = ticket.check_in
      expect(result).to be false
    end
  end

  describe '#check_in!' do
    it 'checks in and saves the ticket' do
      ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
      ticket.check_in!(authorized: true)
      ticket.reload
      expect(ticket.checked_in_at).to be_present
      expect(ticket.authorized).to be true
    end

    it 'raises error if save fails' do
      ticket = FactoryBot.create(:ticket, conference:, sponsorship:)
      ticket.update!(checked_in_at: 1.hour.ago)

      expect {
        ticket.check_in!
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'CODE_CHARS constant' do
    it 'excludes confusing characters' do
      expect(Ticket::CODE_CHARS).not_to include('0', '1', 'O', 'L', 'I', 'K', 'F')
    end

    it 'includes numbers 2-9' do
      expect(Ticket::CODE_CHARS).to include('2', '3', '4', '5', '6', '7', '8', '9')
    end

    it 'includes letters A-Z except excluded ones' do
      ('A'..'Z').each do |letter|
        next if %w[O L I K F].include?(letter)
        expect(Ticket::CODE_CHARS).to include(letter)
      end
    end
  end
end
