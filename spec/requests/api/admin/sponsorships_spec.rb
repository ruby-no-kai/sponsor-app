# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService sponsorships', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:) }
  let(:other_conference) { FactoryBot.create(:conference, :full) }

  before do
    allow(ProcessSponsorshipEditJob).to receive(:perform_later)
  end

  describe 'GetSponsorship' do
    let(:rpc) { connect_method('AdminService', 'GetSponsorship') }

    def request_for(sponsorship, slug: conference.slug)
      Rk::SponsorApp::AdminServiceGetSponsorshipRequest.new(conference_slug: slug, sponsorship_id: sponsorship.id)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'returns the sponsorship as its staff page shows it over POST JSON' do
        plan.update!(booth_size: 2, number_of_guests: 3, words_limit: 20, price_text: 'JPY 1,000')
        sponsorship.update!(
          accepted: true, booth_requested: true, booth_assigned: true, number_of_additional_attendees: 2,
          fallback_option: 'gold', customization_name: 'Gold Plus', profile: 'We make tools for Rubyists',
        )
        sponsorship.contact.update!(email_cc: 'cc@example.invalid')

        result = connect_call(rpc, request_for(sponsorship)).sponsorship

        expect(result).to have_attributes(
          id: sponsorship.id,
          name: sponsorship.name,
          state: :SPONSORSHIP_STATE_ACTIVE,
          accepted_at: Google::Protobuf::Timestamp.new(seconds: sponsorship.accepted_at.to_i, nanos: sponsorship.accepted_at.nsec),
          withdrawn_at: nil,
          suspended: false,
          locale: 'en',
          asset_file_uploaded: true,
          fallback_option: 'gold',
          customization: false,
          customization_name: 'Gold Plus',
          booth_requested: true,
          booth_assigned: true,
          included_attendees: 3,
          number_of_additional_attendees: 2,
          total_attendees: 5,
          url: sponsorship.url,
          profile: 'We make tools for Rubyists',
          word_count: 5,
          has_alternate_billing_contact?: false,
          has_expense_report?: false,
          has_exhibition_description?: false,
        )
        expect(result.plan).to have_attributes(
          id: plan.id, name: plan.name, price_text: 'JPY 1,000', number_of_guests: 3, booth_size: 2,
          words_limit: 20, words_limit_hard: 22,
        )
        expect(result.organization).to have_attributes(domain: sponsorship.organization.domain, name: sponsorship.organization.name)
        expect(result.contact).to have_attributes(
          email: sponsorship.contact.email,
          email_cc: 'cc@example.invalid',
          name: sponsorship.contact.name,
          has_unit?: false,
          compose_email_url: ApplicationController.helpers.front_mail_to_link(
            sponsorship.contact.email, from: conference.contact_email_address, cc: ['cc@example.invalid'],
          ),
        )
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        expected = connect_call(rpc, request_for(sponsorship))

        expect(connect_call(rpc, request_for(sponsorship), via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for(sponsorship), via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for(sponsorship), codec: :proto)).to eq(expected)
      end

      it 'leaves the plan out while it is undetermined' do
        sponsorship.update!(plan: nil)

        expect(connect_call(rpc, request_for(sponsorship)).sponsorship).to have_attributes(
          has_plan?: false, included_attendees: 0, has_number_of_additional_attendees?: false,
        )
      end

      it 'returns the requests, the exhibition and the alternate billing contact' do
        sponsorship.create_billing_request!(body: 'Invoice to HQ')
        sponsorship.create_note!(body: 'See you')
        sponsorship.create_exhibition!(description: 'A demo of our gem')
        sponsorship.create_alternate_billing_contact!(email: 'billing@example.invalid', address: 'Tokyo', organization: 'Contoso', name: 'Billing', unit: 'Accounting')

        result = connect_call(rpc, request_for(sponsorship)).sponsorship

        expect(result).to have_attributes(billing_request: 'Invoice to HQ', note: 'See you', customization_request: '',
          exhibition_description: 'A demo of our gem')
        expect(result.alternate_billing_contact).to have_attributes(email: 'billing@example.invalid', unit: 'Accounting')
      end

      it "returns the discount codes' URLs when the conference sells tickets through the ticketing service" do
        FactoryBot.create(:tito_discount_code, sponsorship:, kind: :booth_staff, code: 'STAFF1')
        FactoryBot.create(:tito_discount_code, sponsorship:, kind: :attendee, code: 'ATTEND1')

        expect(connect_call(rpc, request_for(sponsorship)).sponsorship.tito_discount_codes).to be_empty

        conference.update!(tito_slug: 'rubykaigi/2026')
        codes = connect_call(rpc, request_for(sponsorship)).sponsorship.tito_discount_codes

        expect(codes.map { [it.kind, it.code] }).to eq([[:KIND_ATTENDEE, 'ATTEND1'], [:KIND_BOOTH_STAFF, 'STAFF1']])
        expect(codes.first).to have_attributes(
          registration_url: 'https://ti.to/rubykaigi/2026/discount/ATTEND1',
          dashboard_url: 'https://dashboard.tito.io/rubykaigi/2026/registrations/?search%5Bq%5D=ATTEND1',
        )
      end

      it 'returns the events earliest first and the expense report of a custom package' do
        sponsorship.update!(customization: true, customization_name: 'Ruby Lounge')
        later = FactoryBot.create(:sponsor_event, :accepted, sponsorship:, starts_at: 2.weeks.from_now)
        earlier = FactoryBot.create(:sponsor_event, :pending, sponsorship:, starts_at: 1.week.from_now)
        FactoryBot.create(:expense_report, sponsorship:, status: 'submitted', total_amount: 1200, total_tax_amount: 120)

        result = connect_call(rpc, request_for(sponsorship)).sponsorship

        expect(result.sponsor_events.map { [it.id, it.status] }).to eq([[earlier.id, :SPONSOR_EVENT_STATUS_PENDING], [later.id, :SPONSOR_EVENT_STATUS_ACCEPTED]])
        expect(result.expense_report).to have_attributes(status: :STATUS_SUBMITTED, total_amount: '1200.0', total_tax_amount: '120.0')
      end

      it 'returns the pinned staff notes and the five latest others' do
        author = FactoryBot.create(:staff, login: 'author')
        pinned = SponsorshipStaffNote.create!(sponsorship:, staff: author, body: '**Pinned**', stickiness: 1)
        notes = Array.new(6) { |i| SponsorshipStaffNote.create!(sponsorship:, staff: author, body: "Note #{i}", created_at: i.hours.from_now) }

        result = connect_call(rpc, request_for(sponsorship))

        expect(result.pinned_staff_notes.map(&:id)).to eq([pinned.id])
        expect(result.pinned_staff_notes.first).to have_attributes(pinned: true, staff_login: 'author', body: '**Pinned**')
        expect(result.pinned_staff_notes.first.body_html).to include('<strong>Pinned</strong>')
        expect(result.recent_staff_notes.map(&:id)).to eq(notes.reverse.first(5).map(&:id))
      end

      it "offers the conference's plans and the fallback options of the sponsorship's locale" do
        platinum = plan
        gold = FactoryBot.create(:plan, conference:, name: 'Gold', rank: -1)
        conference.form_descriptions.find_by!(locale: 'en').update!(fallback_options: Rk::SponsorApp::Internal::FallbackOptions.new(options: [
          Rk::SponsorApp::Internal::FallbackOption.new(value: 'withdraw', name: 'Withdraw'),
        ]))
        FactoryBot.create(:form_description, conference:, locale: 'ja', fallback_options: Rk::SponsorApp::Internal::FallbackOptions.new(options: [
          Rk::SponsorApp::Internal::FallbackOption.new(value: 'gold', name: 'ゴールドに変更'),
        ]))

        en = connect_call(rpc, request_for(sponsorship))
        sponsorship.update!(locale: 'ja')
        ja = connect_call(rpc, request_for(sponsorship))

        expect(en.plan_choices.map(&:id)).to eq([gold.id, platinum.id])
        expect(en.fallback_option_choices.map(&:value)).to eq(['withdraw'])
        expect(ja.fallback_option_choices.map(&:name)).to eq(['ゴールドに変更'])
        expect(en.impersonation_enabled).to be(false)
      end

      it 'offers plans of the same rank oldest first' do
        later = FactoryBot.create(:plan, conference:, name: 'Gold', rank: plan.rank)
        plan.update!(updated_at: Time.zone.now) # rewrites the row after the later plan's, so only the ID orders them

        expect(connect_call(rpc, request_for(sponsorship)).plan_choices.map(&:id)).to eq([plan.id, later.id])
      end

      it 'answers not_found for a sponsorship of another conference' do
        elsewhere = FactoryBot.create(:sponsorship, conference: other_conference, plan: other_conference.plans.first)

        error = connect_call(rpc, request_for(elsewhere))

        expect(error).to have_attributes(status: 404, code: 'not_found')
        expect(problem_type_of(error)).to eq('not-found')
        expect(connect_call(rpc, request_for(elsewhere, slug: other_conference.slug)).sponsorship.id).to eq(elsewhere.id)
      end

      it 'answers invalid_argument for a sponsorship ID that cannot exist' do
        error = connect_call(rpc, Rk::SponsorApp::AdminServiceGetSponsorshipRequest.new(conference_slug: conference.slug, sponsorship_id: 0))

        expect(violations_of(error)).to eq([['sponsorshipId', 'INT64_GT']])
      end
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, request_for(sponsorship))).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for(sponsorship))).to have_attributes(status: 403, code: 'permission_denied')
    end

    it 'returns a sponsorship of a conference restricted staff are admitted to' do
      conference.update!(allow_restricted_access: true, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for(sponsorship)).sponsorship.id).to eq(sponsorship.id)
    end
  end

  describe 'UpdateSponsorship' do
    let(:rpc) { connect_method('AdminService', 'UpdateSponsorship') }

    def contact(**fields)
      Rk::SponsorApp::AdminSponsorshipInput::Contact.new(
        email: 'new@example.invalid', address: 'Nagoya', organization: 'Contoso', name: 'New Contact',
        **fields,
      )
    end

    def input(**fields)
      Rk::SponsorApp::AdminSponsorshipInput.new(
        plan_id: plan.id,
        name: 'Renamed',
        url: 'https://renamed.example.invalid',
        profile: 'Renamed profile',
        booth_requested: true,
        booth_assigned: false,
        fallback_option: '',
        customization: false,
        suspended: false,
        accepted: true,
        contact: contact,
        **fields,
      )
    end

    def request_with(input, sponsorship_id: sponsorship.id)
      Rk::SponsorApp::AdminServiceUpdateSponsorshipRequest.new(conference_slug: conference.slug, sponsorship_id:, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'replaces every field, recording the staff member in the editing history' do
        result = connect_call(rpc, request_with(input(number_of_additional_attendees: 4, fallback_option: 'gold',
          customization_name: 'Ruby Lounge', customization: true))).sponsorship

        expect(result).to have_attributes(name: 'Renamed', state: :SPONSORSHIP_STATE_ACTIVE, booth_requested: true,
          number_of_additional_attendees: 4, customization_name: 'Ruby Lounge')
        expect(sponsorship.reload).to have_attributes(
          name: 'Renamed', url: 'https://renamed.example.invalid', profile: 'Renamed profile', booth_requested: true,
          fallback_option: 'gold', customization: true, customization_name: 'Ruby Lounge', number_of_additional_attendees: 4,
        )
        expect(sponsorship).to be_accepted
        expect(sponsorship.contact).to have_attributes(email: 'new@example.invalid', email_cc: nil, address: 'Nagoya', unit: nil,
          name: 'New Contact')

        history = sponsorship.editing_histories.reorder(:id).last
        expect(history.staff).to eq(staff)
        expect(history.raw).to include('name' => 'Renamed')
        expect(ProcessSponsorshipEditJob).to have_received(:perform_later).with(history)
      end

      it 'keeps absent optional strings null, recording no change for them' do
        sponsorship.contact.update!(unit: nil, email_cc: nil)
        connect_call(rpc, request_with(input(name: sponsorship.name, contact: contact(**sponsorship.contact.slice(:email, :address, :organization, :name).symbolize_keys))))

        expect(sponsorship.reload.customization_name).to be_nil
        expect(sponsorship.contact).to have_attributes(unit: nil, email_cc: nil)
        expect(sponsorship.editing_histories.reorder(:id).last.diff.map { it[1] }).not_to include('contact.unit', 'contact.email_cc', 'customization_name')
      end

      it 'keeps blank optional strings as stored when they are absent, recording no change for them' do
        sponsorship.update!(customization_name: '')
        sponsorship.contact.update!(unit: '', email_cc: '')
        sponsorship.create_alternate_billing_contact!(
          email: 'billing@example.invalid', address: 'Tokyo', organization: 'Contoso', unit: '', name: 'Billing',
        )
        sponsorship.reload.save!
        billing = Rk::SponsorApp::AdminSponsorshipInput::BillingContact.new(
          email: 'billing@example.invalid', address: 'Tokyo', organization: 'Contoso', name: 'Billing',
        )
        stored = sponsorship.contact.slice(:email, :address, :organization, :name).symbolize_keys
        connect_call(rpc, request_with(input(name: sponsorship.name, url: sponsorship.url, profile: sponsorship.profile,
          booth_requested: sponsorship.booth_requested, booth_assigned: sponsorship.booth_assigned, accepted: sponsorship.accepted?,
          customization: sponsorship.customization, contact: contact(**stored), alternate_billing_contact: billing)))

        expect(sponsorship.reload.customization_name).to eq('')
        expect(sponsorship.contact).to have_attributes(unit: '', email_cc: '')
        expect(sponsorship.alternate_billing_contact.unit).to eq('')
        diff_paths = sponsorship.editing_histories.reorder(:id).last.diff.map { it[1] }
        expect(diff_paths).not_to include('contact.unit', 'contact.email_cc', 'customization_name', 'alternate_billing_contact')
      end

      it 'returns what GetSponsorship returns afterwards' do
        updated = connect_call(rpc, request_with(input)).sponsorship
        get_request = Rk::SponsorApp::AdminServiceGetSponsorshipRequest.new(conference_slug: conference.slug, sponsorship_id: sponsorship.id)

        expect(connect_call(connect_method('AdminService', 'GetSponsorship'), get_request).sponsorship).to eq(updated)
      end

      it 'keeps when the sponsorship was accepted, and clears it on unaccepting' do
        sponsorship.update!(accepted_at: Time.zone.local(2026, 4, 1))

        connect_call(rpc, request_with(input(accepted: true)))
        expect(sponsorship.reload.accepted_at).to eq(Time.zone.local(2026, 4, 1))

        connect_call(rpc, request_with(input(accepted: false)))
        expect(sponsorship.reload.accepted_at).to be_nil
      end

      it 'leaves the plan undetermined without a plan ID' do
        result = connect_call(rpc, request_with(input(plan_id: nil))).sponsorship

        expect(result.has_plan?).to be(false)
        expect(sponsorship.reload.plan).to be_nil
      end

      it 'moves the sponsorship to another plan of the conference' do
        gold = FactoryBot.create(:plan, conference:, name: 'Gold')

        expect(connect_call(rpc, request_with(input(plan_id: gold.id))).sponsorship.plan.name).to eq('Gold')
      end

      it 'answers not_found for a plan of another conference, changing nothing' do
        error = connect_call(rpc, request_with(input(plan_id: other_conference.plans.first.id)))

        expect(error).to have_attributes(status: 404, code: 'not_found')
        expect(sponsorship.reload).to have_attributes(name: sponsorship.name, plan: plan)
        expect(ProcessSponsorshipEditJob).not_to have_received(:perform_later)
      end

      it 'answers not_found for a sponsorship of another conference' do
        elsewhere = FactoryBot.create(:sponsorship, conference: other_conference, plan: other_conference.plans.first)

        expect(connect_call(rpc, request_with(input, sponsorship_id: elsewhere.id))).to have_attributes(code: 'not_found')
        expect(elsewhere.reload.name).not_to eq('Renamed')
      end

      it 'adds, changes and removes the alternate billing contact' do
        billing = Rk::SponsorApp::AdminSponsorshipInput::BillingContact.new(
          email: 'billing@example.invalid', address: 'Tokyo', organization: 'Contoso', unit: 'Accounting', name: 'Billing',
        )

        connect_call(rpc, request_with(input(alternate_billing_contact: billing)))
        expect(sponsorship.reload.alternate_billing_contact).to have_attributes(kind: 'billing', email: 'billing@example.invalid', unit: 'Accounting')

        billing.email = 'invoices@example.invalid'
        connect_call(rpc, request_with(input(alternate_billing_contact: billing)))
        expect(sponsorship.reload.alternate_billing_contact.email).to eq('invoices@example.invalid')
        expect(sponsorship.contacts.count).to eq(2)

        result = connect_call(rpc, request_with(input)).sponsorship
        expect(result.has_alternate_billing_contact?).to be(false)
        expect(sponsorship.reload.alternate_billing_contact).to be_nil

        history = sponsorship.editing_histories.reorder(:id).last
        expect(history.raw['alternate_billing_contact']).to be_nil
        expect(history.diff).to include(
          ['~', 'alternate_billing_contact', include('email' => 'invoices@example.invalid'), nil],
        )
      end

      it 'creates, changes and removes the requests, a blank body removing one' do
        connect_call(rpc, request_with(input(billing_request: 'Invoice to HQ', customization_request: 'A lounge', note: 'Hello')))
        expect(sponsorship.reload).to have_attributes(
          billing_request: have_attributes(kind: 'billing', body: 'Invoice to HQ'),
          customization_request: have_attributes(kind: 'customization', body: 'A lounge'),
          note: have_attributes(kind: 'note', body: 'Hello'),
        )

        result = connect_call(rpc, request_with(input(billing_request: 'Invoice to the branch', note: " \n"))).sponsorship
        expect(result).to have_attributes(billing_request: 'Invoice to the branch', customization_request: '', note: '')
        expect(sponsorship.reload).to have_attributes(customization_request: nil, note: nil)
        expect(sponsorship.billing_request.body).to eq('Invoice to the branch')

        history = sponsorship.editing_histories.reorder(:id).last
        expect(history.raw).to include('billing_request' => 'Invoice to the branch', 'customization_request' => nil, 'note' => nil)
        expect(history.diff).to include(['~', 'customization_request', 'A lounge', nil], ['~', 'note', 'Hello', nil])
      end

      it 'answers invalid_argument naming a contact email that is no address' do
        error = connect_call(rpc, request_with(input(contact: contact(email: 'nobody'))))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to eq([['input.contact.email', 'STRING_EMAIL']])
        expect(sponsorship.reload.name).not_to eq('Renamed')
      end

      it 'names the field as a binary request spells it' do
        error = connect_call(rpc, request_with(input(number_of_additional_attendees: -1)), codec: :proto)

        expect(violations_of(error)).to eq([['input.number_of_additional_attendees', 'INT32_GTE']])
      end

      it 'answers the invalid-record problem naming the fields the record rejects, nested ones included' do
        error = connect_call(rpc, request_with(input(name: ' ', contact: contact(email_cc: 'nobody, cc@example.invalid'))))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(error.detail(Protobufable::ProblemDetails)).to have_attributes(type: 'https://sponsorships.rubykaigi.org/problems/invalid-record', status: 422)
        expect(violations_of(error)).to contain_exactly(['input.contact.emailCc', 'INVALID_VALUE'], ['input.name', 'BLANK'])
        expect(sponsorship.reload.contact.email).not_to eq('new@example.invalid')
        expect(ProcessSponsorshipEditJob).not_to have_received(:perform_later)
      end

      it 'refuses GET, as updating has side effects' do
        get "#{rpc.path}?#{URI.encode_www_form(connect: 'v1', encoding: 'json', message: request_with(input).to_json)}"

        expect(response).to have_http_status(:method_not_allowed)
      end
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_with(input(contact: contact(email: 'nobody'))))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input))).to have_attributes(code: 'permission_denied')
      expect(sponsorship.reload.name).not_to eq('Renamed')
    end
  end

  describe 'WithdrawSponsorship' do
    let(:rpc) { connect_method('AdminService', 'WithdrawSponsorship') }

    def request_for(sponsorship)
      Rk::SponsorApp::AdminServiceWithdrawSponsorshipRequest.new(conference_slug: conference.slug, sponsorship_id: sponsorship.id)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'withdraws the sponsorship, releasing its plan and booth, as the staff member' do
        sponsorship.update!(accepted: true, booth_assigned: true)

        result = connect_call(rpc, request_for(sponsorship)).sponsorship

        expect(result).to have_attributes(state: :SPONSORSHIP_STATE_WITHDRAWN, booth_assigned: false, has_plan?: false)
        expect(result.withdrawn_at).to be_present
        expect(sponsorship.reload).to have_attributes(withdrawn?: true, booth_assigned: false, plan: nil)
        history = sponsorship.editing_histories.reorder(:id).last
        expect(history.staff).to eq(staff)
        expect(ProcessSponsorshipEditJob).to have_received(:perform_later).with(history)
      end

      it 'answers failed_precondition for a sponsorship already withdrawn' do
        sponsorship.withdraw.save!
        withdrawn_at = sponsorship.reload.withdrawn_at

        error = connect_call(rpc, request_for(sponsorship))

        expect(error).to have_attributes(code: 'failed_precondition')
        expect(problem_type_of(error)).to eq('failed-precondition')
        expect(sponsorship.reload.withdrawn_at).to eq(withdrawn_at)
        expect(ProcessSponsorshipEditJob).not_to have_received(:perform_later)
      end

      it 'answers not_found for a sponsorship of another conference' do
        elsewhere = FactoryBot.create(:sponsorship, conference: other_conference, plan: other_conference.plans.first)

        expect(connect_call(rpc, request_for(elsewhere))).to have_attributes(code: 'not_found')
        expect(elsewhere.reload).not_to be_withdrawn
      end

      it 'answers invalid_argument for a sponsorship ID that cannot exist' do
        error = connect_call(rpc, Rk::SponsorApp::AdminServiceWithdrawSponsorshipRequest.new(conference_slug: conference.slug, sponsorship_id: 0))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to eq([['sponsorshipId', 'INT64_GT']])
      end
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, request_for(sponsorship))).to have_attributes(status: 401, code: 'unauthenticated')
      expect(sponsorship.reload).not_to be_withdrawn
      expect(ProcessSponsorshipEditJob).not_to have_received(:perform_later)
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for(sponsorship))).to have_attributes(code: 'permission_denied')
      expect(sponsorship.reload).not_to be_withdrawn
    end
  end
end
