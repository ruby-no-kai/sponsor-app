# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService broadcasts', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:other_conference) { FactoryBot.create(:conference, :full) }

  before do
    allow(CreateBroadcastDeliveriesJob).to receive(:perform_later)
  end

  def sponsorship_of(conference, **attributes)
    FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first, **attributes)
  end

  def input(**fields)
    Rk::SponsorApp::BroadcastInput.new(
      campaign: 'cfp-reminder',
      description: 'Reminds sponsors of the CFP',
      title: 'Sponsor session CFP closes soon',
      body: "Hello,\n\n**The CFP** closes on Friday.",
      **fields,
    )
  end

  describe 'ListBroadcasts' do
    let(:rpc) { connect_method('AdminService', 'ListBroadcasts') }

    def request_for(slug = conference.slug) = Rk::SponsorApp::AdminServiceListBroadcastsRequest.new(conference_slug: slug)

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it "lists the conference's broadcasts newest first" do
        dispatched_at = Time.zone.parse('2026-03-01 10:00:00')
        sent = FactoryBot.create(:broadcast, conference:, campaign: 'welcome', title: 'Welcome', status: :sent, dispatched_at:)
        draft = FactoryBot.create(:broadcast, conference:, campaign: 'cfp', title: 'CFP', status: :ready)
        FactoryBot.create(:broadcast, conference: other_conference)

        broadcasts = connect_call(rpc, request_for).broadcasts

        expect(broadcasts).to eq([
          Rk::SponsorApp::AdminBroadcastSummary.new(id: draft.id, campaign: 'cfp', title: 'CFP', status: :STATUS_READY),
          Rk::SponsorApp::AdminBroadcastSummary.new(id: sent.id, campaign: 'welcome', title: 'Welcome', status: :STATUS_SENT,
            dispatched_at: Google::Protobuf::Timestamp.from_time(dispatched_at)),
        ])
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        FactoryBot.create(:broadcast, conference:)
        expected = connect_call(rpc, request_for)

        expect(connect_call(rpc, request_for, via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for, via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for, codec: :proto)).to eq(expected)
      end

      it 'answers not_found for an unknown conference' do
        expect(connect_call(rpc, request_for('nothing'))).to have_attributes(status: 404, code: 'not_found')
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

  describe 'GetBroadcast' do
    let(:rpc) { connect_method('AdminService', 'GetBroadcast') }
    let(:broadcast) { FactoryBot.create(:broadcast, conference:, status: :ready, body: "Hi @LOGIN@\n\n*Thanks*") }

    def request_for(broadcast_id, slug: conference.slug)
      Rk::SponsorApp::AdminServiceGetBroadcastRequest.new(conference_slug: slug, broadcast_id:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'returns the broadcast with its body rendered' do
        result = connect_call(rpc, request_for(broadcast.id)).broadcast

        expect(result).to eq(Rk::SponsorApp::AdminBroadcast.new(
          id: broadcast.id,
          campaign: broadcast.campaign,
          description: broadcast.description,
          title: broadcast.title,
          body: "Hi @LOGIN@\n\n*Thanks*",
          body_html: broadcast.html.to_str,
          status: :STATUS_READY,
          content_locked: false,
        ))
        expect(result.body_html).to include('<em>Thanks</em>')
      end

      it "lists recipients, sponsors' by name then addresses added as is, each with its address and copies" do
        zeta = sponsorship_of(conference, name: 'Zeta')
        alpha = sponsorship_of(conference, name: 'Alpha')
        alpha.contact.update!(email_cc: 'cc1@alpha.invalid, cc2@alpha.invalid')
        raw = FactoryBot.create(:broadcast_delivery, broadcast:, recipient: 'raw@example.invalid', status: :ready)
        to_zeta = FactoryBot.create(:broadcast_delivery, broadcast:, sponsorship: zeta, recipient: zeta.contact.email, status: :ready)
        to_alpha = FactoryBot.create(:broadcast_delivery, broadcast:, sponsorship: alpha, recipient: alpha.contact.email,
          recipient_cc: 'cc1@alpha.invalid,cc2@alpha.invalid', status: :ready)

        deliveries = connect_call(rpc, request_for(broadcast.id)).deliveries

        expect(deliveries.map(&:id)).to eq([to_alpha.id, to_zeta.id, raw.id])
        expect(deliveries.first).to eq(Rk::SponsorApp::AdminBroadcastDelivery.new(
          id: to_alpha.id,
          sponsorship: Rk::SponsorApp::AdminBroadcastDelivery::Sponsorship.new(id: alpha.id, name: 'Alpha', conference_slug: conference.slug),
          email: alpha.contact.email,
          cc_emails: ['cc1@alpha.invalid', 'cc2@alpha.invalid'],
          status: :STATUS_READY,
        ))
        expect(deliveries.last).to have_attributes(sponsorship: nil, email: 'raw@example.invalid', cc_emails: [])
      end

      it "names a past sponsor's own conference" do
        past = sponsorship_of(other_conference)
        FactoryBot.create(:broadcast_delivery, broadcast:, sponsorship: past, recipient: past.contact.email, status: :ready)

        expect(connect_call(rpc, request_for(broadcast.id)).deliveries.sole.sponsorship.conference_slug).to eq(other_conference.slug)
      end

      it 'reads every delivery status' do
        BroadcastDelivery.statuses.each_key { FactoryBot.create(:broadcast_delivery, broadcast:, status: it) }

        statuses = connect_call(rpc, request_for(broadcast.id)).deliveries.map(&:status)

        expect(statuses).to match_array(BroadcastDelivery.statuses.keys.map { :"STATUS_#{it.upcase}" })
      end

      it 'locks the content of a dispatched broadcast' do
        broadcast.update!(status: :sending, dispatched_at: Time.zone.parse('2026-03-01 10:00:00'))

        expect(connect_call(rpc, request_for(broadcast.id)).broadcast).to have_attributes(
          status: :STATUS_SENDING,
          content_locked: true,
          dispatched_at: Google::Protobuf::Timestamp.from_time(Time.zone.parse('2026-03-01 10:00:00')),
        )
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        FactoryBot.create(:broadcast_delivery, broadcast:, status: :ready)
        expected = connect_call(rpc, request_for(broadcast.id))

        expect(connect_call(rpc, request_for(broadcast.id), via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for(broadcast.id), via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for(broadcast.id), codec: :proto)).to eq(expected)
      end

      it 'reads deliveries in as many queries however many there are' do
        sponsorship = sponsorship_of(conference)
        FactoryBot.create(:broadcast_delivery, broadcast:, sponsorship:, status: :ready)
        baseline = query_count { connect_call(rpc, request_for(broadcast.id)) }
        3.times do
          FactoryBot.create(:broadcast_delivery, broadcast:, sponsorship: sponsorship_of(other_conference), status: :ready)
        end

        expect(query_count { connect_call(rpc, request_for(broadcast.id)) }).to eq(baseline)
      end

      it 'answers not_found for a broadcast of another conference' do
        other = FactoryBot.create(:broadcast, conference: other_conference)

        expect(connect_call(rpc, request_for(other.id))).to have_attributes(status: 404, code: 'not_found')
        expect(connect_call(rpc, request_for(broadcast.id, slug: other_conference.slug))).to have_attributes(code: 'not_found')
      end

      it 'answers invalid_argument for a broadcast ID that cannot exist' do
        expect(violations_of(connect_call(rpc, request_for(0)))).to eq([['broadcastId', 'INT64_GT']])
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_for(0))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for(broadcast.id))).to have_attributes(code: 'permission_denied')
    end

    it 'returns a broadcast of a conference restricted staff are admitted to' do
      conference.update!(allow_restricted_access: true, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for(broadcast.id)).broadcast.id).to eq(broadcast.id)
    end
  end

  describe 'CreateBroadcast' do
    let(:rpc) { connect_method('AdminService', 'CreateBroadcast') }

    def request_with(input, slug: conference.slug)
      Rk::SponsorApp::AdminServiceCreateBroadcastRequest.new(conference_slug: slug, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'creates the broadcast signed by the staff member, collecting no recipients' do
        result = connect_call(rpc, request_with(input)).broadcast

        broadcast = conference.broadcasts.find(result.id)
        expect(broadcast).to have_attributes(
          staff:,
          status: 'created',
          campaign: 'cfp-reminder',
          description: 'Reminds sponsors of the CFP',
          title: 'Sponsor session CFP closes soon',
          body: "Hello,\n\n**The CFP** closes on Friday.",
        )
        expect(result).to have_attributes(status: :STATUS_CREATED, content_locked: false)
        expect(result.body_html).to include('<strong>The CFP</strong>')
        expect(CreateBroadcastDeliveriesJob).to have_received(:perform_later).with(broadcast, [])
      end

      it 'makes the broadcast ready once the job has run' do
        allow(CreateBroadcastDeliveriesJob).to receive(:perform_later).and_call_original

        result = connect_call(rpc, request_with(input))

        broadcast = conference.broadcasts.find(result.broadcast.id)
        expect(broadcast).to be_ready
        expect(broadcast.deliveries).to be_empty
      end

      it 'answers invalid_argument with a violation per broken rule, creating nothing' do
        error = connect_call(rpc, request_with(input(campaign: ' ', title: '', body: "\n")))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to contain_exactly(
          ['input.campaign', 'BROADCAST_INPUT_CAMPAIGN_NOT_BLANK'],
          ['input.title', 'REQUIRED'],
          ['input.body', 'BROADCAST_INPUT_BODY_NOT_BLANK'],
        )
        expect(conference.broadcasts).to be_empty
      end

      it 'creates over binary protobuf too' do
        result = connect_call(rpc, request_with(input), codec: :proto)

        expect(result.broadcast.campaign).to eq('cfp-reminder')
        expect(CreateBroadcastDeliveriesJob).to have_received(:perform_later).with(conference.broadcasts.find(result.broadcast.id), [])
      end

      it "answers invalid_argument naming the campaign when another of the conference's broadcasts has it" do
        FactoryBot.create(:broadcast, conference:, campaign: 'cfp-reminder')
        FactoryBot.create(:broadcast, conference: other_conference, campaign: 'unique-elsewhere')

        error = connect_call(rpc, request_with(input))

        expect(error).to have_attributes(code: 'invalid_argument')
        expect(problem_type_of(error)).to eq('invalid-record')
        expect(violations_of(error)).to eq([['input.campaign', 'TAKEN']])
        expect(connect_call(rpc, request_with(input(campaign: 'unique-elsewhere')))).to be_a(Rk::SponsorApp::AdminServiceCreateBroadcastResponse)
      end

      it 'answers aborted with the conflict problem when a concurrent save takes the campaign after validation' do
        allow(Broadcast).to receive(:new).and_wrap_original do |new_broadcast, *args|
          new_broadcast.call(*args).tap do |broadcast|
            allow(broadcast).to receive(:valid?).and_wrap_original do |valid, *valid_args|
              # insert! bypasses Broadcast.new, which this example wraps.
              rival = {conference_id: conference.id, staff_id: staff.id, campaign: 'cfp-reminder', description: '', title: 'Rival', body: 'Rival', status: 0}
              valid.call(*valid_args).tap { Broadcast.insert!(rival) } # rubocop:disable Rails/SkipsModelValidations
            end
          end
        end

        error = connect_call(rpc, request_with(input))

        expect(error).to have_attributes(status: 409, code: 'aborted')
        expect(problem_type_of(error)).to eq('conflict')
        expect(error.message).to include('cfp-reminder')
        expect(CreateBroadcastDeliveriesJob).not_to have_received(:perform_later)
      end

      it 'refuses GET, as creating has side effects' do
        get "#{rpc.path}?#{URI.encode_www_form(connect: 'v1', encoding: 'json', message: request_with(input).to_json)}"

        expect(response).to have_http_status(:method_not_allowed)
      end
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_with(input(title: '')))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input))).to have_attributes(code: 'permission_denied')
      expect(conference.broadcasts).to be_empty
    end
  end

  describe 'UpdateBroadcast' do
    let(:rpc) { connect_method('AdminService', 'UpdateBroadcast') }
    let(:broadcast) { FactoryBot.create(:broadcast, conference:, status: :ready) }

    def request_with(input, broadcast_id: broadcast.id)
      Rk::SponsorApp::AdminServiceUpdateBroadcastRequest.new(conference_slug: conference.slug, broadcast_id:, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'replaces every field' do
        result = connect_call(rpc, request_with(input)).broadcast

        expect(broadcast.reload).to have_attributes(
          campaign: 'cfp-reminder',
          description: 'Reminds sponsors of the CFP',
          title: 'Sponsor session CFP closes soon',
          body: "Hello,\n\n**The CFP** closes on Friday.",
          status: 'ready',
        )
        expect(result).to have_attributes(id: broadcast.id, title: 'Sponsor session CFP closes soon', status: :STATUS_READY)
      end

      it 'returns what GetBroadcast returns afterwards' do
        updated = connect_call(rpc, request_with(input)).broadcast
        get_request = Rk::SponsorApp::AdminServiceGetBroadcastRequest.new(conference_slug: conference.slug, broadcast_id: broadcast.id)

        expect(connect_call(connect_method('AdminService', 'GetBroadcast'), get_request).broadcast).to eq(updated)
      end

      it 'updates over binary protobuf too' do
        expect(connect_call(rpc, request_with(input), codec: :proto).broadcast.title).to eq('Sponsor session CFP closes soon')
        expect(broadcast.reload.campaign).to eq('cfp-reminder')
      end

      [:pending, :sending, :sent].each do |status|
        it "answers invalid_argument naming the title and body of a #{status} broadcast, changing nothing" do
          broadcast.update!(status:)

          error = connect_call(rpc, request_with(input(campaign: broadcast.campaign, description: 'Renamed')))

          expect(problem_type_of(error)).to eq('invalid-record')
          expect(violations_of(error)).to contain_exactly(['input.title', 'INVALID_VALUE'], ['input.body', 'INVALID_VALUE'])
          expect(broadcast.reload.description).not_to eq('Renamed')
        end

        it "changes the campaign and description of a #{status} broadcast" do
          broadcast.update!(status:)

          connect_call(rpc, request_with(input(title: broadcast.title, body: broadcast.body)))

          expect(broadcast.reload).to have_attributes(campaign: 'cfp-reminder', description: 'Reminds sponsors of the CFP')
        end
      end

      it 'answers not_found for a broadcast of another conference, leaving it as it was' do
        other = FactoryBot.create(:broadcast, conference: other_conference)

        expect(connect_call(rpc, request_with(input, broadcast_id: other.id))).to have_attributes(code: 'not_found')
        expect(other.reload.campaign).not_to eq('cfp-reminder')
      end

      it 'answers invalid_argument without an input' do
        expect(violations_of(connect_call(rpc, request_with(nil)))).to eq([['input', 'REQUIRED']])
      end
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_with(input(title: '')))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input))).to have_attributes(code: 'permission_denied')
      expect(broadcast.reload.campaign).not_to eq('cfp-reminder')
    end
  end
end
