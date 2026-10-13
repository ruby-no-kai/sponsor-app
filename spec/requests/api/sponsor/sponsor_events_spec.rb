# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService events', type: :request do
  let(:form_rpc) { connect_method('SponsorService', 'GetSponsorEventForm') }
  let(:get_rpc) { connect_method('SponsorService', 'GetSponsorEvent') }
  let(:create_rpc) { connect_method('SponsorService', 'CreateSponsorEvent') }
  let(:update_rpc) { connect_method('SponsorService', 'UpdateSponsorEvent') }
  let(:withdraw_rpc) { connect_method('SponsorService', 'WithdrawSponsorEvent') }

  let(:conference) { FactoryBot.create(:conference, :full, event_submission_starts_at: 1.day.ago) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first, accepted_at: 1.hour.ago) }
  let(:starts_at) { Time.utc(2048, 9, 10, 19, 0, 0) }
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true, region: 'ap-northeast-1') }

  before do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    allow(ProcessSponsorEventEditJob).to receive(:perform_later)
  end

  def last_history(event) = SponsorEventEditingHistory.where(sponsor_event_id: event.id).order(:id).last

  def timestamp(time) = Google::Protobuf::Timestamp.from_time(time)

  def input(**fields)
    Rk::SponsorApp::SponsorEventInput.new(
      title: 'Ruby Night', starts_at: timestamp(starts_at), url: 'https://night.example.invalid',
      price: 'Free', capacity: '100', location_en: 'Tokyo', location_local: '東京', **fields
    )
  end

  def create_request(input = input(), slug: conference.slug, policy_agreement: true)
    Rk::SponsorApp::SponsorServiceCreateSponsorEventRequest.new(conference_slug: slug, input:, policy_agreement:)
  end

  def update_request(event, input = input(), slug: conference.slug)
    Rk::SponsorApp::SponsorServiceUpdateSponsorEventRequest.new(conference_slug: slug, id: event.id, input:)
  end

  def get_request(event, slug: conference.slug)
    Rk::SponsorApp::SponsorServiceGetSponsorEventRequest.new(conference_slug: slug, id: event.id)
  end

  def withdraw_request(event) = Rk::SponsorApp::SponsorServiceWithdrawSponsorEventRequest.new(conference_slug: conference.slug, id: event.id)

  def form_request = Rk::SponsorApp::SponsorServiceGetSponsorEventFormRequest.new(conference_slug: conference.slug)

  def unclaimed_image(owner = sponsorship, **attributes)
    SponsorEventAssetFile.prepare(conference:, sponsorship: owner).tap { it.update!(extension: 'png', **attributes) }
  end

  it 'answers unauthenticated without a sponsor session' do
    expect(connect_call(form_rpc, form_request)).to have_attributes(code: 'unauthenticated')
  end

  context 'with a sponsor session' do
    before { sign_in_sponsor(sponsorship.contact.email) }

    let!(:event) do
      FactoryBot.create(:sponsor_event, :pending, :with_details, sponsorship:, title: 'Existing', starts_at:,
        admin_comment: 'Please shorten the title')
    end

    shared_examples 'an RPC on events' do
      it 'answers failed_precondition while the sponsorship is not accepted' do
        sponsorship.update!(accepted_at: nil)

        error = call
        expect(error).to have_attributes(code: 'failed_precondition', message: I18n.t('sponsor_events.sponsorship_not_accepted'))
      end
    end

    shared_examples 'an RPC changing events' do
      it 'answers failed_precondition while event submission is not open' do
        conference.update!(event_submission_starts_at: 1.day.from_now)

        expect(call).to have_attributes(code: 'failed_precondition', message: I18n.t('sponsor_events.event_submission_not_open'))
      end
    end

    describe 'GetSponsorEventForm' do
      let(:call) { connect_call(form_rpc, form_request) }

      it_behaves_like 'an RPC on events'

      it "returns the conference's texts in the browser's locale" do
        conference.form_descriptions.first.update!(sponsor_event_help: 'Help me', event_policy: 'Be nice')
        FactoryBot.create(:form_description, conference:, locale: 'ja', sponsor_event_help: 'ヘルプ', event_policy: '礼儀')

        expect(connect_call(form_rpc, form_request, via: :get)).to have_attributes(
          conference: have_attributes(slug: conference.slug),
          submission_open: true,
          sponsor_event_help_html: a_string_including('Help me'),
          event_policy_html: a_string_including('Be nice'),
        )
        expect(connect_call(form_rpc, form_request, via: :get, headers: {'Accept-Language' => 'ja'})).to have_attributes(
          sponsor_event_help_html: a_string_including('ヘルプ'),
        )
      end

      it 'answers without texts for a conference described in no locale' do
        conference.form_descriptions.destroy_all

        expect(call).to have_attributes(sponsor_event_help_html: '', event_policy_html: '')
      end

      it 'answers while submission is closed, reporting it' do
        conference.update!(event_submission_starts_at: nil)

        expect(call).to have_attributes(submission_open: false)
      end
    end

    describe 'GetSponsorEvent' do
      let(:call) { connect_call(get_rpc, get_request(event)) }

      it_behaves_like 'an RPC on events'

      it 'returns what the sponsor sees, as editable while submission is open' do
        asset_file = unclaimed_image(sponsor_event: event)

        result = connect_call(get_rpc, get_request(event), via: :get)

        expect(result.conference.slug).to eq(conference.slug)
        expect(result.sponsor_event).to have_attributes(
          id: event.id, title: 'Existing', starts_at: timestamp(starts_at), url: event.url,
          price: 'Free', capacity: '100 people', location_en: 'Tokyo', location_local: '東京',
          status: :SPONSOR_EVENT_STATUS_PENDING, admin_comment: 'Please shorten the title',
          asset_file: have_attributes(id: asset_file.id, extension: 'png'), editable: true,
        )
        expect(result.sponsor_event.policy_acknowledged_at).not_to be_nil
      end

      it 'is not editable once submission closes or the event is withdrawn' do
        conference.update!(event_submission_starts_at: 1.day.from_now)
        expect(connect_call(get_rpc, get_request(event)).sponsor_event.editable).to be(false)

        conference.update!(event_submission_starts_at: 1.day.ago)
        event.update!(status: :withdrawn)
        expect(connect_call(get_rpc, get_request(event)).sponsor_event).to have_attributes(editable: false, status: :SPONSOR_EVENT_STATUS_WITHDRAWN)
      end

      it "answers not_found for another sponsorship's event" do
        other = FactoryBot.create(:sponsor_event, sponsorship: FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first))

        expect(connect_call(get_rpc, get_request(other))).to have_attributes(code: 'not_found')
      end

      it 'answers not_found for an event of the same sponsor in another conference slug' do
        other_conference = FactoryBot.create(:conference, :full)

        expect(connect_call(get_rpc, get_request(event, slug: other_conference.slug))).to have_attributes(code: 'not_found')
      end
    end

    describe 'CreateSponsorEvent' do
      let(:call) { connect_call(create_rpc, create_request) }

      it_behaves_like 'an RPC on events'
      it_behaves_like 'an RPC changing events'

      it 'submits a pending event, acknowledges the policy and enqueues the job with a staff-less history' do
        result = connect_call(create_rpc, create_request).sponsor_event

        saved = sponsorship.sponsor_events.find(result.id)
        expect(saved).to have_attributes(
          title: 'Ruby Night', starts_at:, url: 'https://night.example.invalid', price: 'Free', capacity: '100',
          location_en: 'Tokyo', location_local: '東京', status: 'pending', conference_id: conference.id,
          co_host_sponsorship_ids: [], link_name: '', admin_comment: '',
        )
        expect(saved.policy_acknowledged_at).to be_within(1.minute).of(Time.zone.now)
        expect(saved.slug).to be_present
        expect(result).to have_attributes(status: :SPONSOR_EVENT_STATUS_PENDING, editable: true)
        expect(saved.editing_histories.sole).to have_attributes(staff: nil)
        expect(ProcessSponsorEventEditJob).to have_received(:perform_later).with(last_history(saved))
      end

      it 'claims an uploaded image' do
        asset_file = unclaimed_image

        result = connect_call(create_rpc, create_request(input(asset_file_id: asset_file.id))).sponsor_event

        expect(result.asset_file).to have_attributes(id: asset_file.id, extension: 'png')
        expect(asset_file.reload.sponsor_event_id).to eq(result.id)
      end

      it 'answers not_found for an image another sponsorship uploaded' do
        foreign = unclaimed_image(FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first))

        expect(connect_call(create_rpc, create_request(input(asset_file_id: foreign.id)))).to have_attributes(code: 'not_found')
        expect(SponsorEvent.where(title: 'Ruby Night')).to be_empty
      end

      it 'answers not_found for an image an event has claimed' do
        attached = unclaimed_image(sponsor_event: event)

        expect(connect_call(create_rpc, create_request(input(asset_file_id: attached.id)))).to have_attributes(code: 'not_found')
      end

      it 'answers invalid_argument without the policy agreement' do
        error = connect_call(create_rpc, create_request(policy_agreement: false))

        expect(violations_of(error)).to eq([['policyAgreement', 'POLICY_AGREEMENT_AGREED']])
        expect(SponsorEvent.where(title: 'Ruby Night')).to be_empty
      end

      it 'answers invalid_argument naming the Input fields' do
        error = connect_call(create_rpc, create_request(input(title: ' ', url: 'ftp://x.invalid')))

        expect(error).to have_attributes(code: 'invalid_argument')
        expect(violations_of(error).map(&:first)).to contain_exactly('input.title', 'input.url')
      end

      it 'ignores the staff fields a hostile client adds to the JSON' do
        post create_rpc.path,
          params: {
            conferenceSlug: conference.slug, policyAgreement: true,
            input: {title: 'X', startsAt: starts_at.iso8601, url: 'https://x.invalid', status: 'SPONSOR_EVENT_STATUS_ACCEPTED', slug: 'mine', adminComment: 'ok'},
          }.to_json,
          headers: {'Content-Type' => 'application/json', 'Connect-Protocol-Version' => '1'}

        expect(response).to have_http_status(:ok)
        expect(SponsorEvent.find_by!(title: 'X')).to have_attributes(status: 'pending', admin_comment: '')
        expect(SponsorEvent.find_by!(title: 'X').slug).not_to eq('mine')
      end

      it 'answers not_found for a conference the contact does not sponsor' do
        other = FactoryBot.create(:conference, :full, event_submission_starts_at: 1.day.ago)

        expect(connect_call(create_rpc, create_request(slug: other.slug))).to have_attributes(code: 'not_found')
      end
    end

    describe 'UpdateSponsorEvent' do
      let(:call) { connect_call(update_rpc, update_request(event)) }

      it_behaves_like 'an RPC on events'
      it_behaves_like 'an RPC changing events'

      it 'replaces every writable field and leaves the staff fields' do
        event.update!(link_name: 'Register', slug: 'kept')

        result = connect_call(update_rpc, update_request(event, input(title: 'Renamed', price: '', capacity: ''))).sponsor_event

        expect(result).to have_attributes(title: 'Renamed', price: '', editable: true)
        expect(event.reload).to have_attributes(
          title: 'Renamed', price: '', capacity: '', link_name: 'Register', slug: 'kept', admin_comment: 'Please shorten the title',
        )
        expect(last_history(event)).to have_attributes(staff: nil)
        expect(ProcessSponsorEventEditJob).to have_received(:perform_later).with(last_history(event))
      end

      it 'answers failed_precondition for a withdrawn event' do
        event.update!(status: :withdrawn)

        expect(call).to have_attributes(code: 'failed_precondition', message: I18n.t('sponsor_events.update.withdrawn_not_editable'))
        expect(ProcessSponsorEventEditJob).not_to have_received(:perform_later)
      end

      it "answers not_found for another sponsorship's event" do
        other = FactoryBot.create(:sponsor_event, sponsorship: FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first))

        expect(connect_call(update_rpc, update_request(other))).to have_attributes(code: 'not_found')
        expect(other.reload.title).not_to eq('Ruby Night')
      end

      it 'answers invalid_argument for a rule violation' do
        error = connect_call(update_rpc, update_request(event, input(url: 'nope')))

        expect(violations_of(error).map(&:first)).to eq(['input.url'])
      end
    end

    describe 'UpdateSponsorEvent with an image' do
      let!(:current_image) { unclaimed_image(sponsor_event: event) }

      before { allow(s3_client).to receive(:delete_object) }

      it 'removes it when the Input names none' do
        connect_call(update_rpc, update_request(event))

        expect(SponsorEventAssetFile.exists?(current_image.id)).to be(false)
        expect(s3_client).to have_received(:delete_object).with(bucket: anything, key: a_string_including("--#{current_image.id}"))
      end

      it 'keeps it when the Input names it' do
        result = connect_call(update_rpc, update_request(event, input(asset_file_id: current_image.id))).sponsor_event

        expect(result.asset_file.id).to eq(current_image.id)
        expect(event.reload.asset_file).to eq(current_image)
        expect(s3_client).not_to have_received(:delete_object)
      end

      it 'swaps it for another upload, destroying the old one' do
        replacement = unclaimed_image

        result = connect_call(update_rpc, update_request(event, input(asset_file_id: replacement.id))).sponsor_event

        expect(result.asset_file.id).to eq(replacement.id)
        expect(event.reload.asset_file).to eq(replacement)
        expect(SponsorEventAssetFile.exists?(current_image.id)).to be(false)
        expect(s3_client).to have_received(:delete_object).once
      end

      it 'answers not_found for an image an event has claimed' do
        other_event = FactoryBot.create(:sponsor_event, sponsorship:)
        claimed = unclaimed_image(sponsor_event: other_event)

        expect(connect_call(update_rpc, update_request(event, input(asset_file_id: claimed.id)))).to have_attributes(code: 'not_found')
        expect(event.reload.asset_file).to eq(current_image)
      end

      it 'keeps the old image and its object when the update fails' do
        replacement = unclaimed_image
        allow_any_instance_of(SponsorEvent).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(event)) # rubocop:disable RSpec/AnyInstance

        error = connect_call(update_rpc, update_request(event, input(asset_file_id: replacement.id)))

        expect(error).to have_attributes(code: 'invalid_argument')
        expect(event.reload.asset_file).to eq(current_image)
        expect(replacement.reload.sponsor_event_id).to be_nil
        expect(s3_client).not_to have_received(:delete_object)
      end
    end

    describe 'WithdrawSponsorEvent' do
      let(:call) { connect_call(withdraw_rpc, withdraw_request(event)) }

      it_behaves_like 'an RPC on events'
      it_behaves_like 'an RPC changing events'

      it 'withdraws the event and enqueues the job with a staff-less history' do
        result = call.sponsor_event

        expect(result).to have_attributes(status: :SPONSOR_EVENT_STATUS_WITHDRAWN, editable: false)
        expect(event.reload.status).to eq('withdrawn')
        expect(last_history(event)).to have_attributes(staff: nil)
        expect(ProcessSponsorEventEditJob).to have_received(:perform_later).with(last_history(event))
      end

      it 'answers failed_precondition for an event withdrawn already' do
        event.update!(status: :withdrawn)

        expect(call).to have_attributes(code: 'failed_precondition')
      end

      it "answers not_found for another sponsorship's event" do
        other = FactoryBot.create(:sponsor_event, sponsorship: FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first))

        expect(connect_call(withdraw_rpc, withdraw_request(other))).to have_attributes(code: 'not_found')
        expect(other.reload.status).to eq('pending')
      end
    end
  end
end
