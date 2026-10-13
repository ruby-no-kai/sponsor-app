# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService broadcast deliveries', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first }
  let(:past_conference) { FactoryBot.create(:conference, :full) }
  let(:broadcast) { FactoryBot.create(:broadcast, conference:, status: :ready) }

  before do
    allow(CreateBroadcastDeliveriesJob).to receive(:perform_later)
  end

  def sponsorship_of(conference, **attributes)
    FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first, **attributes)
  end

  def filter(kind, **fields) = Rk::SponsorApp::BroadcastRecipientFilter.new(kind => fields)

  # The job's argument for a filter of the given kind.
  def queued_message(kind, **fields)
    filter_class = Rk::SponsorApp::Internal::BroadcastRecipientFilter.const_get(kind.to_s.camelize)
    Rk::SponsorApp::Internal::BroadcastRecipientFilter.new(kind => filter_class.new(**fields))
  end

  def admit_restricted_staff(conference)
    conference.update!(allow_restricted_access: true, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
  end

  describe 'AddBroadcastRecipients' do
    let(:rpc) { connect_method('AdminService', 'AddBroadcastRecipients') }

    def request_with(recipient_filter, broadcast_id: broadcast.id, slug: conference.slug)
      Rk::SponsorApp::AdminServiceAddBroadcastRecipientsRequest.new(conference_slug: slug, broadcast_id:, recipient_filter:)
    end

    # The job's argument for the request.
    def queued_filter(recipient_filter)
      queued = []
      allow(CreateBroadcastDeliveriesJob).to receive(:perform_later) { |_broadcast, filters| queued.concat(filters) }
      connect_call(rpc, request_with(recipient_filter))
      queued.sole
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'marks the broadcast modifying while the job adds the recipients' do
        result = connect_call(rpc, request_with(filter(:raw, emails: ['a@example.invalid'])))

        expect(result.broadcast).to have_attributes(id: broadcast.id, status: :STATUS_MODIFYING)
        expect(broadcast.reload).to be_modifying
        expect(CreateBroadcastDeliveriesJob).to have_received(:perform_later).with(broadcast, [queued_message(:raw, emails: ['a@example.invalid'])])
      end

      it 'queues current sponsors with every field the filter declares' do
        expect(queued_filter(filter(:current_sponsors, locale: 'en', exhibitors_only: true, plan_id: plan.id,
          status: :SPONSORSHIP_STATUS_NOT_ACCEPTED))).to eq(
            queued_message(:current_sponsors, locale: 'en', exhibitors_only: true, plan_id: plan.id, status: :SPONSORSHIP_STATUS_NOT_ACCEPTED),
          )
      end

      it 'leaves the current sponsor fields left unset' do
        expect(queued_filter(filter(:current_sponsors))).to eq(queued_message(:current_sponsors))
      end

      it 'queues past sponsors by the id of the conference the slug names' do
        expect(queued_filter(filter(:past_sponsors, conference_slug: past_conference.slug, locale: 'ja',
          exclude_current_sponsors: true, status: :SPONSORSHIP_STATUS_WITHDRAWN))).to eq(
            queued_message(:past_sponsors, conference_id: past_conference.id, locale: 'ja', exclude_current_sponsors: true,
              status: :SPONSORSHIP_STATUS_WITHDRAWN),
          )
      end

      it 'queues sponsorships picked one by one' do
        picked = [sponsorship_of(conference), sponsorship_of(conference)]

        expect(queued_filter(filter(:manual, sponsorship_ids: picked.map(&:id)))).to eq(queued_message(:manual, sponsorship_ids: picked.map(&:id)))
      end

      it 'queues the addresses' do
        expect(queued_filter(filter(:raw, emails: ['a@example.invalid', 'b@example.invalid'])))
          .to eq(queued_message(:raw, emails: ['a@example.invalid', 'b@example.invalid']))
      end

      [:created, :preparing, :modifying, :pending, :sending, :sent].each do |status|
        it "answers failed_precondition for a #{status} broadcast, queueing nothing" do
          broadcast.update!(status:)

          error = connect_call(rpc, request_with(filter(:raw, emails: ['a@example.invalid'])))

          expect(error).to have_attributes(code: 'failed_precondition')
          expect(problem_type_of(error)).to eq('failed-precondition')
          expect(broadcast.reload.status).to eq(status.to_s)
          expect(CreateBroadcastDeliveriesJob).not_to have_received(:perform_later)
        end
      end

      it 'answers not_found for sponsorships of another conference, queueing nothing' do
        theirs = sponsorship_of(past_conference)

        error = connect_call(rpc, request_with(filter(:manual, sponsorship_ids: [sponsorship_of(conference).id, theirs.id])))

        expect(error).to have_attributes(code: 'not_found')
        expect(error.message).to include(theirs.id.to_s)
        expect(broadcast.reload).to be_ready
        expect(CreateBroadcastDeliveriesJob).not_to have_received(:perform_later)
      end

      it 'answers not_found for a plan of another conference, queueing nothing' do
        error = connect_call(rpc, request_with(filter(:current_sponsors, plan_id: past_conference.plans.first.id)))

        expect(error).to have_attributes(code: 'not_found')
        expect(CreateBroadcastDeliveriesJob).not_to have_received(:perform_later)
      end

      it 'answers not_found for past sponsors of an unknown conference' do
        expect(connect_call(rpc, request_with(filter(:past_sponsors, conference_slug: 'nothing')))).to have_attributes(code: 'not_found')
      end

      it 'answers not_found for a broadcast of another conference' do
        other = FactoryBot.create(:broadcast, conference: past_conference, status: :ready)

        expect(connect_call(rpc, request_with(filter(:raw, emails: ['a@example.invalid']), broadcast_id: other.id)))
          .to have_attributes(code: 'not_found')
        expect(other.reload).to be_ready
      end

      it 'answers invalid_argument with a violation per broken rule' do
        error = connect_call(rpc, request_with(filter(:raw, emails: ['a@example.invalid', 'a@example.invalid', 'nope'])))

        expect(violations_of(error)).to contain_exactly(
          ['recipientFilter.raw.emails', 'REPEATED_UNIQUE'],
          ['recipientFilter.raw.emails[2]', 'STRING_EMAIL'],
        )
        expect(CreateBroadcastDeliveriesJob).not_to have_received(:perform_later)
      end

      it 'answers invalid_argument for an empty selection' do
        expect(violations_of(connect_call(rpc, request_with(filter(:manual)))))
          .to eq([['recipientFilter.manual.sponsorshipIds', 'REPEATED_MIN_ITEMS']])
        expect(violations_of(connect_call(rpc, request_with(filter(:current_sponsors, locale: 'fr')))))
          .to eq([['recipientFilter.currentSponsors.locale', 'STRING_IN']])
      end

      it 'answers invalid_argument without a filter' do
        expect(violations_of(connect_call(rpc, request_with(nil)))).to eq([['recipientFilter', 'REQUIRED']])
      end

      it 'adds over binary protobuf too' do
        picked = [sponsorship_of(conference), sponsorship_of(conference)]

        result = connect_call(rpc, request_with(filter(:manual, sponsorship_ids: picked.map(&:id))), codec: :proto)

        expect(result.broadcast.status).to eq(:STATUS_MODIFYING)
        expect(CreateBroadcastDeliveriesJob).to have_received(:perform_later)
          .with(broadcast, [queued_message(:manual, sponsorship_ids: picked.map(&:id))])
      end

      it 'names the field as a binary request spells it' do
        error = connect_call(rpc, request_with(filter(:past_sponsors, conference_slug: 'Not A Slug')), codec: :proto)

        expect(violations_of(error)).to eq([['recipient_filter.past_sponsors.conference_slug', 'STRING_PATTERN']])
      end
    end

    context 'with a staff session, running the job' do
      before do
        sign_in_staff(staff)
        allow(CreateBroadcastDeliveriesJob).to receive(:perform_later).and_call_original
      end

      def recipients_after(recipient_filter)
        connect_call(rpc, request_with(recipient_filter))
        expect(broadcast.reload).to be_ready
        broadcast.deliveries.pluck(:recipient)
      end

      it 'adds the current sponsors the filter picks' do
        gold = FactoryBot.create(:plan, conference:, name: 'Gold')
        picked = sponsorship_of(conference, plan: gold, locale: 'ja', booth_assigned: true, accepted_at: Time.current)
        sponsorship_of(conference, plan: gold, locale: 'ja', booth_assigned: true)
        sponsorship_of(conference, plan: gold, locale: 'en', booth_assigned: true, accepted_at: Time.current)
        sponsorship_of(conference, plan: gold, locale: 'ja', accepted_at: Time.current)
        sponsorship_of(conference, locale: 'ja', booth_assigned: true, accepted_at: Time.current)

        expect(recipients_after(filter(:current_sponsors, locale: 'ja', exhibitors_only: true, plan_id: gold.id,
          status: :SPONSORSHIP_STATUS_ACTIVE))).to eq([picked.contact.email])
      end

      it 'adds the past sponsors the filter picks' do
        picked = sponsorship_of(past_conference, locale: 'en')
        sponsorship_of(past_conference, locale: 'ja')
        sponsorship_of(conference, locale: 'en')

        expect(recipients_after(filter(:past_sponsors, conference_slug: past_conference.slug, locale: 'en')))
          .to eq([picked.contact.email])
      end

      it 'adds the sponsorships picked, copying their contacts' do
        picked = sponsorship_of(conference)
        picked.contact.update!(email_cc: 'cc@example.invalid')
        sponsorship_of(conference)

        expect(recipients_after(filter(:manual, sponsorship_ids: [picked.id]))).to eq([picked.contact.email])
        expect(broadcast.deliveries.sole).to have_attributes(sponsorship: picked, recipient_cc: 'cc@example.invalid')
      end

      it 'adds the addresses, skipping those the broadcast already has' do
        FactoryBot.create(:broadcast_delivery, broadcast:, recipient: 'a@example.invalid', status: :ready)

        expect(recipients_after(filter(:raw, emails: ['a@example.invalid', 'b@example.invalid'])))
          .to contain_exactly('a@example.invalid', 'b@example.invalid')
      end
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_with(nil))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(filter(:raw, emails: ['a@example.invalid'])))).to have_attributes(code: 'permission_denied')
      expect(broadcast.reload).to be_ready
    end

    context 'with restricted staff admitted to the conference' do
      before do
        admit_restricted_staff(conference)
        sign_in_staff(restricted_staff)
      end

      it 'answers permission_denied for past sponsors of a conference they may not manage, queueing nothing' do
        error = connect_call(rpc, request_with(filter(:past_sponsors, conference_slug: past_conference.slug)))

        expect(error).to have_attributes(code: 'permission_denied')
        expect(error.message).to include(past_conference.slug)
        expect(broadcast.reload).to be_ready
        expect(CreateBroadcastDeliveriesJob).not_to have_received(:perform_later)
      end

      it 'queues past sponsors of a conference they may manage' do
        admit_restricted_staff(past_conference)

        expect(connect_call(rpc, request_with(filter(:past_sponsors, conference_slug: past_conference.slug))).broadcast.status)
          .to eq(:STATUS_MODIFYING)
      end
    end
  end

  describe 'RemoveBroadcastDelivery' do
    let(:rpc) { connect_method('AdminService', 'RemoveBroadcastDelivery') }
    let!(:delivery) { FactoryBot.create(:broadcast_delivery, broadcast:, status: :ready) }

    def request_for(delivery_id = delivery.id, broadcast_id: broadcast.id)
      Rk::SponsorApp::AdminServiceRemoveBroadcastDeliveryRequest.new(conference_slug: conference.slug, broadcast_id:, delivery_id:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'removes a ready delivery of a ready broadcast' do
        expect(connect_call(rpc, request_for)).to eq(Rk::SponsorApp::AdminServiceRemoveBroadcastDeliveryResponse.new)
        expect(BroadcastDelivery.exists?(delivery.id)).to be(false)
      end

      [:pending, :sending, :sent, :failed, :delivered].each do |status|
        it "answers failed_precondition for a #{status} delivery, keeping it" do
          delivery.update!(status:)

          expect(connect_call(rpc, request_for)).to have_attributes(code: 'failed_precondition')
          expect(delivery.reload.status).to eq(status.to_s)
        end
      end

      [:modifying, :pending, :sending].each do |status|
        it "answers failed_precondition for a delivery of a #{status} broadcast, keeping it" do
          broadcast.update!(status:)

          expect(connect_call(rpc, request_for)).to have_attributes(code: 'failed_precondition')
          expect(BroadcastDelivery.exists?(delivery.id)).to be(true)
        end
      end

      it 'answers not_found for a delivery of another broadcast, keeping it' do
        other = FactoryBot.create(:broadcast_delivery, broadcast: FactoryBot.create(:broadcast, conference:, status: :ready), status: :ready)

        expect(connect_call(rpc, request_for(other.id))).to have_attributes(code: 'not_found')
        expect(BroadcastDelivery.exists?(other.id)).to be(true)
      end

      it 'refuses GET, as removing has side effects' do
        get "#{rpc.path}?#{URI.encode_www_form(connect: 'v1', encoding: 'json', message: request_for.to_json)}"

        expect(response).to have_http_status(:method_not_allowed)
        expect(BroadcastDelivery.exists?(delivery.id)).to be(true)
      end

      it 'removes over binary protobuf too' do
        expect(connect_call(rpc, request_for, codec: :proto)).to eq(Rk::SponsorApp::AdminServiceRemoveBroadcastDeliveryResponse.new)
        expect(BroadcastDelivery.exists?(delivery.id)).to be(false)
      end

      it 'answers invalid_argument for IDs that cannot exist' do
        expect(violations_of(connect_call(rpc, request_for(0, broadcast_id: 0))))
          .to contain_exactly(['broadcastId', 'INT64_GT'], ['deliveryId', 'INT64_GT'])
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_for(0))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage, keeping the delivery' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for)).to have_attributes(code: 'permission_denied')
      expect(BroadcastDelivery.exists?(delivery.id)).to be(true)
    end
  end
end
