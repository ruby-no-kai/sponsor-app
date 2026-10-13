# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService GetSponsorship', type: :request do
  let(:rpc) { connect_method('SponsorService', 'GetSponsorship') }
  let(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago) }
  let(:plan) { conference.plans.first }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:) }

  def request_for(slug = conference.slug) = Rk::SponsorApp::SponsorServiceGetSponsorshipRequest.new(conference_slug: slug)

  def timestamp(time) = Google::Protobuf::Timestamp.new(seconds: time.to_i, nanos: time.nsec)

  it 'answers unauthenticated without a sponsor session' do
    expect(connect_call(rpc, request_for)).to have_attributes(code: 'unauthenticated')
  end

  context 'with a sponsor session' do
    before { sign_in_sponsor(sponsorship.contact.email) }

    def dashboard = connect_call(rpc, request_for)

    it 'returns the application and the conference as they stand' do
      plan.update!(talkable: true, booth_size: 1)

      result = dashboard

      expect(result.conference).to have_attributes(slug: conference.slug, name: conference.name)
      expect(result.sponsorship).to have_attributes(
        id: sponsorship.id,
        name: sponsorship.name,
        url: sponsorship.url,
        profile: sponsorship.profile,
        locale: 'en',
        state: :SPONSORSHIP_STATE_PENDING,
        plan_name: plan.name,
        customized: false,
        has_customization_name?: false,
        sponsor_talk: true,
        booth_requested: false,
        booth_assigned: false,
        booth_eligible: true,
      )
      expect(result).to have_attributes(
        amendment_open: true,
        event_submission_open: false,
        distributing_tickets: false,
        tickets_on_tito: false,
        has_exhibition?: false,
        has_sponsor_events?: false,
        has_expense_report?: false,
        has_tickets?: false,
        announcements: [],
      )
    end

    it 'answers a GET and a binary call alike' do
      expected = dashboard

      expect(connect_call(rpc, request_for, via: :get)).to eq(expected)
      expect(connect_call(rpc, request_for, codec: :proto)).to eq(expected)
    end

    it 'loads events, discount codes and announcements without a query for each' do
      conference.update!(event_submission_starts_at: 1.day.ago, ticket_distribution_starts_at: 1.day.ago, tito_slug: 'ruby-no-kai/rubykaigi2048')
      sponsorship.update!(accepted: true, booth_assigned: true, customization: true, customization_name: 'Ruby Plus')
      FactoryBot.create(:expense_report, sponsorship:)
      FactoryBot.create(:sponsor_event, sponsorship:)
      FactoryBot.create(:tito_discount_code, sponsorship:, kind: :attendee)
      FactoryBot.create(:announcement, :published, conference:)
      baseline = query_count { dashboard }

      FactoryBot.create(:sponsor_event, sponsorship:)
      FactoryBot.create(:tito_discount_code, sponsorship:, kind: :booth_staff)
      FactoryBot.create(:announcement, :published, conference:)

      expect(query_count { dashboard }).to eq(baseline)
    end

    it 'answers not_found for a conference the contact does not sponsor' do
      other = FactoryBot.create(:conference, :full)
      FactoryBot.create(:sponsorship, conference: other, plan: other.plans.first)

      expect(connect_call(rpc, request_for(other.slug))).to have_attributes(code: 'not_found')
    end

    it 'answers not_found for a withdrawn sponsorship' do
      sponsorship.update!(withdrawn_at: Time.current)

      expect(connect_call(rpc, request_for)).to have_attributes(code: 'not_found')
    end

    it 'answers invalid_argument for a malformed slug' do
      expect(violations_of(connect_call(rpc, request_for('Not A Slug')))).to eq([['conferenceSlug', 'STRING_PATTERN']])
    end

    it 'leaves the plan out while it is undetermined' do
      sponsorship.update!(plan: nil)

      expect(dashboard.sponsorship).to have_attributes(has_plan_name?: false, sponsor_talk: false, booth_eligible: false)
    end

    describe 'custom package' do
      before { plan.update!(talkable: true) }

      it 'keeps a package the organizers have not confirmed to themselves' do
        sponsorship.update!(customization_name: 'Ruby Plus')

        expect(dashboard.sponsorship).to have_attributes(customized: false, has_customization_name?: false, sponsor_talk: false)
      end

      it 'names a confirmed package, which replaces the sponsor talk' do
        sponsorship.update!(customization: true, customization_name: 'Ruby Plus')

        expect(dashboard.sponsorship).to have_attributes(customized: true, customization_name: 'Ruby Plus', sponsor_talk: false)
      end
    end

    describe 'exhibition' do
      before { Exhibition.create!(sponsorship:, description: "Demos\nStickers") }

      it 'describes the exhibit at an assigned booth' do
        sponsorship.update!(booth_assigned: true)

        expect(dashboard.exhibition).to have_attributes(description: "Demos\nStickers")
      end

      it 'is left out without a booth' do
        expect(dashboard.has_exhibition?).to be(false)
      end
    end

    describe 'events' do
      it 'are left out while the sponsorship awaits acceptance' do
        conference.update!(event_submission_starts_at: 1.day.ago)
        FactoryBot.create(:sponsor_event, sponsorship:)

        expect(dashboard.has_sponsor_events?).to be(false)
      end

      it 'are left out of an accepted sponsorship until submission opens or an event exists' do
        sponsorship.update!(accepted: true)
        conference.update!(event_submission_starts_at: 1.day.from_now)

        expect(dashboard).to have_attributes(event_submission_open: false, has_sponsor_events?: false)
      end

      it 'are an empty list once submission opens' do
        sponsorship.update!(accepted: true)
        conference.update!(event_submission_starts_at: 1.day.ago)

        expect(dashboard).to have_attributes(event_submission_open: true, sponsor_events: Rk::SponsorApp::SponsorServiceGetSponsorshipResponse::SponsorEvents.new)
      end

      it 'list submitted events earliest first, whatever their status' do
        sponsorship.update!(accepted: true)
        later = FactoryBot.create(:sponsor_event, :withdrawn, sponsorship:, starts_at: 2.weeks.from_now)
        earlier = FactoryBot.create(:sponsor_event, :accepted, sponsorship:, starts_at: 1.week.from_now)

        events = dashboard.sponsor_events.events

        expect(events.map(&:id)).to eq([earlier.id, later.id])
        expect(events.first).to have_attributes(
          title: earlier.title,
          status: :SPONSOR_EVENT_STATUS_ACCEPTED,
          starts_at: timestamp(earlier.starts_at),
        )
        expect(events.last.status).to eq(:SPONSOR_EVENT_STATUS_WITHDRAWN)
      end
    end

    describe 'expense report' do
      before do
        plan.update!(price: 1_000_000, price_booth: 200_000)
        sponsorship.update!(customization: true, customization_name: 'Ruby Plus', booth_assigned: true)
      end

      it 'weighs the expenses against the fee, booth included' do
        FactoryBot.create(:expense_report, sponsorship:, status: 'submitted', total_amount: 1_300_000)

        expect(dashboard.expense_report).to have_attributes(
          status: :STATUS_SUBMITTED,
          total_amount: '1300000',
          fee: '1200000',
          remaining: '-100000',
        )
      end

      it 'leaves the fee out while the plan is undetermined' do
        FactoryBot.create(:expense_report, sponsorship:, total_amount: 300_000)
        sponsorship.update!(plan: nil)

        expect(dashboard.expense_report).to have_attributes(
          status: :STATUS_DRAFT, total_amount: '300000', has_fee?: false, has_remaining?: false,
        )
      end

      it 'is left out for a confirmed package with no name' do
        FactoryBot.create(:expense_report, sponsorship:)
        sponsorship.update!(customization_name: nil)

        expect(dashboard.has_expense_report?).to be(false)
      end

      it 'is left out until the sponsor starts one' do
        expect(dashboard.has_expense_report?).to be(false)
      end
    end

    describe 'tickets' do
      before do
        plan.update!(number_of_guests: 3)
        sponsorship.update!(number_of_additional_attendees: 2)
      end

      def distribute_tickets(tito_slug: 'ruby-no-kai/rubykaigi2048')
        conference.update!(ticket_distribution_starts_at: 1.day.ago, tito_slug:)
      end

      def create_discount_codes
        [:booth_paid, :attendee, :booth_staff].each { FactoryBot.create(:tito_discount_code, sponsorship:, kind: it, quantity: 99) }
      end

      it 'are left out until the conference distributes them' do
        sponsorship.update!(accepted: true)
        conference.update!(ticket_distribution_starts_at: 1.day.from_now, tito_slug: 'ruby-no-kai/rubykaigi2048')
        create_discount_codes

        expect(dashboard).to have_attributes(distributing_tickets: false, has_tickets?: false)
      end

      it 'are left out for a sponsorship including none' do
        distribute_tickets
        create_discount_codes

        expect(dashboard).to have_attributes(distributing_tickets: true, has_tickets?: false)
      end

      it 'link each code with what the sponsorship includes, not the synced quantity' do
        distribute_tickets
        sponsorship.update!(accepted: true, booth_assigned: true)
        create_discount_codes

        codes = dashboard.tickets.discount_codes

        expect(codes.map(&:kind)).to eq([:KIND_ATTENDEE, :KIND_BOOTH_STAFF, :KIND_BOOTH_PAID])
        expect(codes.map { it.has_quantity? ? it.quantity : nil }).to eq([5, 2, nil])
        expect(codes.first.url).to eq(sponsorship.tito_attendee_discount_code.url)
      end

      it 'show for a booth alone' do
        distribute_tickets
        sponsorship.update!(booth_assigned: true)

        expect(dashboard.tickets).to eq(Rk::SponsorApp::SponsorServiceGetSponsorshipResponse::Tickets.new)
      end

      it 'carry no codes when the conference sells no tickets through the ticketing service' do
        distribute_tickets(tito_slug: nil)
        sponsorship.update!(accepted: true)
        create_discount_codes

        expect(dashboard).to have_attributes(tickets_on_tito: false, tickets: Rk::SponsorApp::SponsorServiceGetSponsorshipResponse::Tickets.new)
      end

      it 'never send the ticket key the codes derive from' do
        distribute_tickets
        sponsorship.update!(accepted: true, booth_assigned: true)
        create_discount_codes

        connect_call(rpc, request_for)

        expect(response.body).to include('ti.to')
        expect(response.body).not_to include(sponsorship.ticket_key)
      end
    end

    describe 'announcements' do
      let(:other_conference) { FactoryBot.create(:conference) }
      let!(:pinned) { FactoryBot.create(:announcement, :published, :pinned, conference:) }
      let!(:older) { FactoryBot.create(:announcement, :published, conference:, body: '**Bold**') }
      let!(:newer) { FactoryBot.create(:announcement, :published, conference:) }
      let!(:exhibitors_only) { FactoryBot.create(:announcement, :published, :exhibitors_only, conference:) }
      let!(:japanese) { FactoryBot.create(:announcement, :published, conference:, locale: 'ja') }

      before do
        FactoryBot.create(:announcement, conference:)
        FactoryBot.create(:announcement, :published, conference: other_conference)
      end

      it 'lists those published for sponsors in the locale, pinned first, then newest first' do
        announcements = dashboard.announcements

        expect(announcements.map(&:issue)).to eq([pinned, newer, older].map(&:issue))
        expect(announcements.last).to have_attributes(
          title: older.title,
          body_html: "<p><strong>Bold</strong></p>\n",
          published_at: timestamp(older.published_at),
        )
      end

      it 'adds those for exhibitors once a booth is assigned' do
        sponsorship.update!(booth_assigned: true)

        expect(dashboard.announcements.map(&:issue)).to eq([pinned, exhibitors_only, newer, older].map(&:issue))
      end

      it 'lists those in the locale the area is shown in' do
        https! # The locale cookie is Secure.
        cookies[Rails.application.config.x.locale_cookie_name] = 'ja'

        expect(dashboard.announcements.map(&:issue)).to eq([japanese.issue])
      end
    end
  end
end
