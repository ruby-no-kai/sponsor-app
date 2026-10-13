# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService ListBroadcastDeliveries', type: :request do
  let(:rpc) { connect_method('SponsorService', 'ListBroadcastDeliveries') }
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }

  def request_for(slug = conference.slug) = Rk::SponsorApp::SponsorServiceListBroadcastDeliveriesRequest.new(conference_slug: slug)

  def timestamp(time) = Google::Protobuf::Timestamp.new(seconds: time.to_i, nanos: time.nsec)

  def deliver(status: :sent, to: sponsorship, **attributes)
    broadcast = FactoryBot.create(:broadcast, conference:, status:, **attributes)
    FactoryBot.create(:broadcast_delivery, broadcast:, sponsorship: to, status: :delivered, recipient: to.contact.email, recipient_cc: 'cc@example.invalid')
    broadcast
  end

  it 'answers unauthenticated without a sponsor session' do
    expect(connect_call(rpc, request_for)).to have_attributes(code: 'unauthenticated')
  end

  context 'with a sponsor session' do
    before { sign_in_sponsor(sponsorship.contact.email) }

    it "lists the sponsorship's sent emails, newest first, without their recipients" do
      older = deliver(dispatched_at: 2.days.ago)
      newer = deliver(dispatched_at: 1.day.ago)

      result = connect_call(rpc, request_for)

      expect(result.conference).to have_attributes(slug: conference.slug, contact_email_address: conference.contact_email_address)
      expect(result.broadcast_deliveries.map(&:broadcast_id)).to eq([newer.id, older.id])
      expect(result.broadcast_deliveries.first).to have_attributes(
        title: newer.title,
        sent_at: timestamp(newer.dispatched_at),
        body_html: newer.html.to_str,
      )
      expect(response.body).not_to include(sponsorship.contact.email, 'cc@example.invalid')
    end

    it 'dates an email never dispatched by its creation' do
      broadcast = deliver(dispatched_at: nil)

      expect(connect_call(rpc, request_for).broadcast_deliveries.sole.sent_at).to eq(timestamp(broadcast.created_at))
    end

    it 'leaves out emails still being sent, hidden ones and those sent to other sponsorships' do
      deliver(status: :sending)
      deliver(hidden: true)
      deliver(to: FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first))

      expect(connect_call(rpc, request_for).broadcast_deliveries).to be_empty
    end

    it 'lists an email once however many times it reached the sponsorship' do
      broadcast = deliver
      FactoryBot.create(:broadcast_delivery, broadcast:, sponsorship:, status: :delivered)

      expect(connect_call(rpc, request_for).broadcast_deliveries.map(&:broadcast_id)).to eq([broadcast.id])
    end

    it 'links each sign-in placeholder to the dashboard' do
      deliver(body: "Sign in at @LOGIN@\n\nor fill the form at @FORM@")
      url = "http://www.example.com/conferences/#{conference.slug}/sponsorship"

      body_html = connect_call(rpc, request_for).broadcast_deliveries.sole.body_html

      expect(body_html).to include(%(Sign in at <a href="#{url}">#{url}</a>), %(fill the form at <a href="#{url}">#{url}</a>))
      expect(body_html).not_to include('@LOGIN@', '@FORM@')
    end

    it 'answers a GET and a binary call alike' do
      deliver
      expected = connect_call(rpc, request_for)

      expect(connect_call(rpc, request_for, via: :get)).to eq(expected)
      expect(connect_call(rpc, request_for, codec: :proto)).to eq(expected)
    end

    it 'answers not_found for a conference the contact does not sponsor' do
      other = FactoryBot.create(:conference, :full)

      expect(connect_call(rpc, request_for(other.slug))).to have_attributes(code: 'not_found')
    end
  end
end
