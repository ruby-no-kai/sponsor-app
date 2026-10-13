# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService booth assignments', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference) }
  let(:large_plan) { FactoryBot.create(:plan, conference:, name: 'Ruby', booth_size: 4) }
  let(:small_plan) { FactoryBot.create(:plan, conference:, name: 'Gold', booth_size: 1) }
  let(:boothless_plan) { FactoryBot.create(:plan, conference:, name: 'Silver', booth_size: nil) }

  let!(:exhibitor) { create_sponsorship('Exhibitor', plan: large_plan, booth_requested: true, booth_assigned: true) }
  let!(:waiting) { create_sponsorship('Waiting', plan: small_plan, booth_requested: true) }
  let!(:unrequested) { create_sponsorship('Unrequested', plan: small_plan, booth_assigned: true) }
  let!(:boothless) { create_sponsorship('Boothless', plan: boothless_plan, booth_requested: true) }
  let!(:pending) { create_sponsorship('Pending', plan: large_plan, accepted: false, booth_requested: true, booth_assigned: true) }

  def create_sponsorship(name, plan:, accepted: true, **attributes)
    FactoryBot.create(:sponsorship, conference:, plan:, name:, accepted_at: (Time.current if accepted), **attributes)
  end

  before do
    create_sponsorship('Withdrawn', plan: nil, booth_requested: true, withdrawn_at: Time.current)
    create_sponsorship('Uninterested', plan: small_plan)
    allow(ProcessSponsorshipEditJob).to receive(:perform_later)
  end

  def assigned_names = conference.sponsorships.where(booth_assigned: true).order(:name).pluck(:name)

  describe 'GetBoothAssignment' do
    let(:rpc) { connect_method('AdminService', 'GetBoothAssignment') }

    def request_for(slug = conference.slug) = Rk::SponsorApp::AdminServiceGetBoothAssignmentRequest.new(conference_slug: slug)

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'sums up the candidates and lists them largest booth first, then by name' do
        booth_assignment = connect_call(rpc, request_for).booth_assignment

        expect(booth_assignment).to have_attributes(
          candidate_count: 4,
          candidate_booth_size: 6,
          requesting_count: 4,
          assigned_count: 2,
          assigned_booth_size: 5,
        )
        expect(booth_assignment.candidates.map { it.sponsorship.name }).to eq(['Exhibitor', 'Unrequested', 'Waiting', 'Boothless'])
        expect(booth_assignment.candidates.map { [it.plan_name, it.booth_size, it.booth_requested, it.sponsorship.booth_assigned] })
          .to eq([['Ruby', 4, true, true], ['Gold', 1, false, true], ['Gold', 1, true, false], ['Silver', 0, true, false]])
        expect(booth_assignment.candidates.first.sponsorship).to have_attributes(
          id: exhibitor.id,
          state: :SPONSORSHIP_STATE_ACTIVE,
          organization: have_attributes(domain: exhibitor.organization.domain),
        )
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        expected = connect_call(rpc, request_for)

        expect(connect_call(rpc, request_for, via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for, via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for, codec: :proto)).to eq(expected)
      end

      it 'lists the candidates in as many queries however many there are' do
        baseline = query_count { connect_call(rpc, request_for) }
        create_sponsorship('Late', plan: FactoryBot.create(:plan, conference:, booth_size: 2), booth_requested: true)

        expect(query_count { connect_call(rpc, request_for) }).to eq(baseline)
      end

      it 'returns nothing to assign for a conference without candidates' do
        expect(connect_call(rpc, request_for(FactoryBot.create(:conference).slug)).booth_assignment)
          .to eq(Rk::SponsorApp::BoothAssignment.new)
      end

      it 'answers not_found for an unknown conference' do
        expect(connect_call(rpc, request_for('nothing'))).to have_attributes(status: 404, code: 'not_found')
      end

      it 'answers invalid_argument for a slug no conference can have' do
        expect(violations_of(connect_call(rpc, request_for('Not A Slug')))).to eq([['conferenceSlug', 'STRING_PATTERN']])
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_for('Not A Slug'))).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for)).to have_attributes(status: 403, code: 'permission_denied')
    end
  end

  describe 'UpdateBoothAssignment' do
    let(:rpc) { connect_method('AdminService', 'UpdateBoothAssignment') }

    def request_with(sponsorships) = request_with_ids(sponsorships.map(&:id))

    def request_with_ids(ids)
      Rk::SponsorApp::AdminServiceUpdateBoothAssignmentRequest.new(
        conference_slug: conference.slug,
        input: Rk::SponsorApp::BoothAssignmentInput.new(assigned_sponsorship_ids: ids),
      )
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'assigns booths to exactly the sponsorships listed, taking them back from the rest' do
        booth_assignment = connect_call(rpc, request_with([waiting, boothless])).booth_assignment

        expect(assigned_names).to eq(['Boothless', 'Waiting'])
        expect(booth_assignment).to have_attributes(candidate_count: 3, assigned_count: 2, assigned_booth_size: 1)
        expect(booth_assignment.candidates.map { [it.sponsorship.name, it.sponsorship.booth_assigned] })
          .to eq([['Exhibitor', false], ['Waiting', true], ['Boothless', true]])
      end

      it 'records the staff member and publishes once per sponsorship it changes' do
        expect { connect_call(rpc, request_with([exhibitor, waiting])) }.to change(SponsorshipEditingHistory, :count).by(3)

        histories = [waiting, unrequested, pending].map { it.editing_histories.reorder(:id).last }
        expect(histories.map(&:staff)).to all(eq(staff))
        expect(histories.map { it.raw.fetch('booth_assigned') }).to eq([true, false, false])
        expect(ProcessSponsorshipEditJob).to have_received(:perform_later).exactly(3).times
        histories.each { expect(ProcessSponsorshipEditJob).to have_received(:perform_later).with(it) }
      end

      it 'takes every booth back for an empty list' do
        booth_assignment = connect_call(rpc, request_with([])).booth_assignment

        expect(assigned_names).to be_empty
        expect(booth_assignment).to have_attributes(assigned_count: 0, assigned_booth_size: 0)
        expect(ProcessSponsorshipEditJob).to have_received(:perform_later).exactly(3).times
      end

      it 'changes and publishes nothing for the list already assigned' do
        expect { connect_call(rpc, request_with([exhibitor, unrequested, pending])) }
          .not_to change(SponsorshipEditingHistory, :count)

        expect(assigned_names).to eq(['Exhibitor', 'Pending', 'Unrequested'])
        expect(ProcessSponsorshipEditJob).not_to have_received(:perform_later)
      end

      it 'publishes only once the assignment has committed' do
        depth = Sponsorship.connection.open_transactions
        depths_at_publish = []
        allow(ProcessSponsorshipEditJob).to receive(:perform_later) { depths_at_publish << Sponsorship.connection.open_transactions }

        connect_call(rpc, request_with([waiting]))

        expect(depths_at_publish).to eq([depth] * 4)
      end

      it 'assigns over binary protobuf too' do
        expect(connect_call(rpc, request_with([waiting]), codec: :proto).booth_assignment.assigned_count).to eq(1)
        expect(assigned_names).to eq(['Waiting'])
      end

      it "answers not_found for another conference's sponsorship as for a missing one, changing nothing" do
        other = FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference), plan: nil)
        missing_id = Sponsorship.maximum(:id) + 1

        foreign = connect_call(rpc, request_with([waiting, other]))
        missing = connect_call(rpc, request_with_ids([waiting.id, missing_id]))

        expect(foreign).to have_attributes(status: 404, code: 'not_found')
        expect(problem_type_of(foreign)).to eq('not-found')
        expect(foreign.message.sub(other.id.to_s, 'ID')).to eq(missing.message.sub(missing_id.to_s, 'ID'))
        expect(assigned_names).to eq(['Exhibitor', 'Pending', 'Unrequested'])
        expect(other.reload.booth_assigned).to be(false)
        expect(ProcessSponsorshipEditJob).not_to have_received(:perform_later)
      end

      it 'answers failed_precondition for a booth to a sponsorship that has withdrawn, changing nothing' do
        withdrawn = conference.sponsorships.find_by!(name: 'Withdrawn')

        error = connect_call(rpc, request_with([waiting, withdrawn]))

        expect(error).to have_attributes(code: 'failed_precondition')
        expect(problem_type_of(error)).to eq('failed-precondition')
        expect(error.message).to include(withdrawn.id.to_s)
        expect(assigned_names).to eq(['Exhibitor', 'Pending', 'Unrequested'])
        expect(ProcessSponsorshipEditJob).not_to have_received(:perform_later)
      end

      it 'answers failed_precondition for a booth to a sponsorship awaiting acceptance that holds none' do
        awaiting = create_sponsorship('Awaiting', plan: small_plan, accepted: false, booth_requested: true)

        expect(connect_call(rpc, request_with([awaiting]))).to have_attributes(code: 'failed_precondition')
        expect(awaiting.reload.booth_assigned).to be(false)
      end

      it 'answers invalid_argument for an ID listed twice' do
        expect(violations_of(connect_call(rpc, request_with([waiting, waiting]))))
          .to eq([['input.assignedSponsorshipIds', 'REPEATED_UNIQUE']])
        expect(waiting.reload.booth_assigned).to be(false)
      end

      it 'answers invalid_argument naming the element for an ID no sponsorship can have' do
        expect(violations_of(connect_call(rpc, request_with_ids([waiting.id, 0]))))
          .to eq([['input.assignedSponsorshipIds[1]', 'INT64_GT']])
      end

      it 'answers invalid_argument without an input' do
        request_message = Rk::SponsorApp::AdminServiceUpdateBoothAssignmentRequest.new(conference_slug: conference.slug)

        expect(violations_of(connect_call(rpc, request_message))).to eq([['input', 'REQUIRED']])
        expect(assigned_names).to eq(['Exhibitor', 'Pending', 'Unrequested'])
      end

      it 'refuses GET, as assigning has side effects' do
        get "#{rpc.path}?#{URI.encode_www_form(connect: 'v1', encoding: 'json', message: request_with([waiting]).to_json)}"

        expect(response).to have_http_status(:method_not_allowed)
        expect(waiting.reload.booth_assigned).to be(false)
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_with([waiting, waiting]))).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage, changing nothing' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with([]))).to have_attributes(status: 403, code: 'permission_denied')
      expect(assigned_names).to eq(['Exhibitor', 'Pending', 'Unrequested'])
    end
  end
end
