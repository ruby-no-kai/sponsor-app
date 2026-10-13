# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService applications', type: :request do
  let(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago) }
  let(:plan) { conference.plans.first }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:) }
  let(:s3_client) do
    Aws::S3::Client.new(
      stub_responses: {
        head_object: {version_id: 'v1', last_modified: Time.zone.now, checksum_sha256: 'sum', content_type: 'image/svg+xml'},
      },
      region: 'ap-northeast-1',
    )
  end

  before do
    allow(Aws::STS::Client).to receive(:new).and_return(Aws::STS::Client.new(stub_responses: true, region: 'ap-northeast-1'))
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
  end

  def slug_request(klass, slug = conference.slug, **fields) = klass.new(conference_slug: slug, **fields)

  # Uploads a logo for the conference the way the browser does before applying.
  def upload_asset_file(target = conference, invite_code: '')
    upload = connect_call(
      connect_method('SponsorService', 'CreateSponsorshipAssetUpload'),
      slug_request(Rk::SponsorApp::SponsorServiceCreateSponsorshipAssetUploadRequest, target.slug, invite_code:, content_type: 'image/svg+xml'),
    ).upload
    SponsorshipAssetFile.find(upload.file_id)
  end

  def sponsorship_input(**fields)
    Rk::SponsorApp::SponsorshipInput.new(
      plan_id: plan.id,
      name: 'Contoso',
      url: 'https://contoso.invalid',
      profile: 'We make tools',
      contact: Rk::SponsorApp::SponsorshipInput::Contact.new(
        email: 'contact@contoso.invalid', address: 'Tokyo', organization: 'Contoso', name: 'Contact',
      ),
      **fields,
    )
  end

  describe 'GetApplicationForm' do
    let(:rpc) { connect_method('SponsorService', 'GetApplicationForm') }

    def form_request(slug = conference.slug, **fields)
      slug_request(Rk::SponsorApp::SponsorServiceGetApplicationFormRequest, slug, **fields)
    end

    it 'returns the form a visitor applies with' do
      plan.update!(name: 'Ruby', price_text: 'JPY 1,000,000', number_of_guests: 3, booth_size: 2, talkable: true, words_limit: 150)

      result = connect_call(rpc, form_request)

      expect(result.form.conference).to have_attributes(slug: conference.slug, name: conference.name)
      expect(result.form.plans.sole).to have_attributes(
        id: plan.id, name: 'Ruby', price_text: 'JPY 1,000,000', number_of_guests: 3, booth_size: 2, booth_eligible: true,
        talkable: true, words_limit: 150, auto_acceptance: true, sold_out: false, closed: false, available: true,
      )
      expect(result.form.description).to have_attributes(locale: 'en', head: conference.form_descriptions.sole.head)
      expect(result).to have_attributes(
        application_open: true,
        staff_override: false,
        already_applied: false,
        has_affiliated_organization_name?: false,
        copy_sources: [],
        has_copied_application?: false,
      )
    end

    it 'answers a GET and a binary call alike' do
      expected = connect_call(rpc, form_request)

      expect(connect_call(rpc, form_request, via: :get)).to eq(expected)
      expect(connect_call(rpc, form_request, codec: :proto)).to eq(expected)
    end

    it 'tells a plan that is sold out or closed' do
      plan.update!(capacity: 1)
      FactoryBot.create(:sponsorship, conference:, plan:, accepted_at: Time.zone.now)
      closed = FactoryBot.create(:plan, conference:, closes_at: 1.hour.ago)

      plans = connect_call(rpc, form_request).form.plans.index_by(&:id)

      expect(plans.fetch(plan.id)).to have_attributes(sold_out: true, closed: false, available: false)
      expect(plans.fetch(closed.id)).to have_attributes(sold_out: false, closed: true, available: false)
    end

    it 'counts sponsorships of every plan in one query' do
      connect_call(rpc, form_request)
      baseline = query_count { connect_call(rpc, form_request) }
      FactoryBot.create_list(:plan, 2, conference:)

      expect(query_count { connect_call(rpc, form_request) }).to eq(baseline)
    end

    context 'with Japanese chosen' do
      before do
        https! # The locale cookie is Secure.
        cookies[Rails.application.config.x.locale_cookie_name] = 'ja'
      end

      it 'describes the form in English when it has no Japanese description' do
        expect(connect_call(rpc, form_request).form.description.locale).to eq('en')
      end

      it 'describes the form in Japanese when it has one' do
        FactoryBot.create(:form_description, conference:, locale: 'ja')

        expect(connect_call(rpc, form_request).form.description.locale).to eq('ja')
      end
    end

    it 'answers failed_precondition for a conference with no form described' do
      conference.form_descriptions.destroy_all

      error = connect_call(rpc, form_request)
      expect(error).to have_attributes(code: 'failed_precondition')
      expect(problem_type_of(error)).to eq('failed-precondition')
    end

    it 'answers not_found for an unknown conference' do
      error = connect_call(rpc, form_request('unknown'))
      expect(error).to have_attributes(code: 'not_found', message: 'No conference has the slug "unknown".')
    end

    context 'when the conference is hidden' do
      before { conference.update!(hidden: true) }

      it 'answers not_found without the invitation code, as for an unknown conference' do
        error = connect_call(rpc, form_request)
        expect(error).to have_attributes(code: 'not_found', message: "No conference has the slug #{conference.slug.inspect}.")
      end

      it 'answers not_found for a wrong invitation code' do
        expect(connect_call(rpc, form_request(invite_code: 'wrong'))).to have_attributes(code: 'not_found')
      end

      it 'returns the form for the invitation code, never giving the code back' do
        result = connect_call(rpc, form_request(invite_code: conference.invite_code))

        expect(result.form.conference.slug).to eq(conference.slug)
        expect(response.body).not_to include(conference.invite_code)
      end

      it 'returns the form without the code to a contact sponsoring the conference' do
        sponsorship = FactoryBot.create(:sponsorship, conference:, plan:)
        sign_in_sponsor(sponsorship.contact.email)

        expect(connect_call(rpc, form_request)).to have_attributes(already_applied: true)
      end
    end

    context 'when the conference takes no applications' do
      it 'returns only the conference before applications open, leaving the draft plans and texts out' do
        conference.update!(application_opens_at: nil)
        plan.update!(price_text: 'JPY 9,999,999 (draft)')

        result = connect_call(rpc, form_request)
        expect(result).to have_attributes(application_open: false, staff_override: false)
        expect(result.form.conference.slug).to eq(conference.slug)
        expect(result.form).to have_attributes(plans: [], has_description?: false)
        expect(response.body).not_to include('9,999,999')
      end

      it 'returns only the conference once applications close, described or not' do
        conference.update!(application_closes_at: 1.hour.ago)
        conference.form_descriptions.destroy_all

        expect(connect_call(rpc, form_request).form).to have_attributes(plans: [], has_description?: false)
      end

      it 'returns the whole form to staff, who may apply anyway' do
        conference.update!(application_opens_at: 1.day.from_now)
        sign_in_staff(FactoryBot.create(:staff))

        result = connect_call(rpc, form_request)
        expect(result).to have_attributes(application_open: false, staff_override: true)
        expect(result.form.plans.map(&:id)).to eq([plan.id])
        expect(result.form.description.locale).to eq('en')
      end
    end

    it "names the organization an affiliation code names, and nothing for one that names none" do
      organization = FactoryBot.create(:organization, name: 'Affiliated Inc.')

      expect(connect_call(rpc, form_request(affiliation: organization.affiliation_code)).affiliated_organization_name).to eq('Affiliated Inc.')
      expect(connect_call(rpc, form_request(affiliation: 'unknown'))).to have_attributes(has_affiliated_organization_name?: false)
    end

    context "with a sponsor session of another conference" do
      let(:past) { FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference, :full), plan: nil) }

      before do
        past.create_alternate_billing_contact!(email: 'billing@contoso.invalid', address: 'Osaka', organization: 'Contoso', name: 'Billing')
        past.create_billing_request!(body: 'Invoice in PDF')
        past.create_note!(body: 'Not copied')
        sign_in_sponsor(past.contact.email)
      end

      it 'offers the sponsorship to copy from' do
        sources = connect_call(rpc, form_request).copy_sources

        expect(sources.map(&:id)).to eq([past.id])
        expect(sources.first.conference.slug).to eq(past.conference.slug)
      end

      it 'fills the form in with the answers that carry over' do
        copied = connect_call(rpc, form_request(sponsorship_id_to_copy: past.id)).copied_application

        expect(copied).to have_attributes(
          name: past.name, url: past.url, profile: past.profile, has_plan_id?: false,
          billing_request: 'Invoice in PDF', note: '', customization_request: '',
        )
        expect(copied.contact).to have_attributes(email: past.contact.email, address: past.contact.address, has_unit?: false)
        expect(copied.alternate_billing_contact).to have_attributes(email: 'billing@contoso.invalid', address: 'Osaka')
        expect(copied.asset_file).to have_attributes(id: past.asset_file.id, extension: 'jpg')
      end

      it 'copies nothing from a withdrawn sponsorship' do
        past.withdraw.save!

        expect(connect_call(rpc, form_request(sponsorship_id_to_copy: past.id))).to have_attributes(has_copied_application?: false)
      end

      it 'copies nothing from a sponsorship the session does not cover' do
        other = FactoryBot.create(:sponsorship, plan: nil)

        expect(connect_call(rpc, form_request(sponsorship_id_to_copy: other.id))).to have_attributes(has_copied_application?: false)
      end
    end
  end

  describe 'CreateSponsorship' do
    let(:rpc) { connect_method('SponsorService', 'CreateSponsorship') }

    before { allow(SponsorshipWelcomeJob).to receive(:perform_later) }

    def create_request(input, slug = conference.slug, policy_agreement: true, **fields)
      slug_request(Rk::SponsorApp::SponsorServiceCreateSponsorshipRequest, slug, input:, policy_agreement:, **fields)
    end

    def apply(**fields) = connect_call(rpc, create_request(sponsorship_input(asset_file_id: upload_asset_file.id, **fields)))

    it 'applies, signing the browser in as the new sponsor' do
      asset_file = upload_asset_file
      result = connect_call(rpc, create_request(sponsorship_input(asset_file_id: asset_file.id)))

      sponsorship = Sponsorship.find(result.sponsorship.id)
      expect(sponsorship).to have_attributes(conference:, plan:, name: 'Contoso', locale: 'en', asset_file:)
      expect(sponsorship).to be_accepted
      expect(sponsorship.organization).to have_attributes(domain: 'contoso.invalid', name: 'Contoso')
      expect(result.sponsorship).to have_attributes(name: 'Contoso', state: :SPONSORSHIP_STATE_ACTIVE)
      expect(SponsorshipWelcomeJob).to have_received(:perform_later).with(sponsorship)
      expect(session[:asset_file_ids]).to eq([])

      viewer = connect_call(connect_method('SponsorService', 'GetViewer'), Rk::SponsorApp::SponsorServiceGetViewerRequest.new).viewer
      expect(viewer).to have_attributes(email: 'contact@contoso.invalid')
      expect(viewer.sponsorships.map(&:id)).to eq([sponsorship.id])
    end

    it 'stores the locale chosen for the browser' do
      https! # The locale cookie is Secure.
      cookies[Rails.application.config.x.locale_cookie_name] = 'ja'

      expect(Sponsorship.find(apply.sponsorship.id).locale).to eq('ja')
    end

    it 'leaves the application pending when the plan says so' do
      plan.update!(auto_acceptance: false)
      expect(Sponsorship.find(apply.sponsorship.id)).not_to be_accepted
    end

    it 'leaves the application pending when the organization says so' do
      FactoryBot.create(:organization, domain: 'contoso.invalid', auto_acceptance_disabled: true)
      expect(Sponsorship.find(apply.sponsorship.id)).not_to be_accepted
    end

    it 'applies as the organization an affiliation code names' do
      organization = FactoryBot.create(:organization)

      input = sponsorship_input(asset_file_id: upload_asset_file.id)
      result = connect_call(rpc, create_request(input, affiliation: organization.affiliation_code))
      expect(Sponsorship.find(result.sponsorship.id).organization).to eq(organization)
    end

    it 'copies the logo of a sponsorship the session covers' do
      past = FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference, :full), plan: nil)
      sign_in_sponsor(past.contact.email)

      result = connect_call(rpc, create_request(sponsorship_input(asset_file_id: past.asset_file.id)))

      copy = Sponsorship.find(result.sponsorship.id).asset_file
      expect(copy.id).not_to eq(past.asset_file.id)
      expect(copy).to have_attributes(extension: 'jpg', prefix: "c-#{conference.id}/", version_id: 'v1')
      expect(past.reload.asset_file.sponsorship).to eq(past)
      expect(s3_client.api_requests.pluck(:operation_name)).to include(:copy_object)
    end

    it 'leaves no copy behind when the application is refused' do
      past = FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference, :full), plan: nil)
      sign_in_sponsor(past.contact.email)

      expect do
        connect_call(rpc, create_request(sponsorship_input(asset_file_id: past.asset_file.id, profile: 'word ' * 20)))
      end.not_to change(SponsorshipAssetFile, :count)
      expect(response.parsed_body).to include('code' => 'invalid_argument')
    end

    it 'answers not_found for a logo this browser did not upload' do
      other = SponsorshipAssetFile.prepare(conference:).tap(&:save!)

      error = connect_call(rpc, create_request(sponsorship_input(asset_file_id: other.id)))
      expect(error).to have_attributes(code: 'not_found')
      expect(Sponsorship.count).to eq(0)
    end

    it 'answers not_found for a logo this browser uploaded for another conference' do
      other = FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago)

      error = connect_call(rpc, create_request(sponsorship_input(asset_file_id: upload_asset_file(other).id)))
      expect(error).to have_attributes(code: 'not_found')
      expect(Sponsorship.count).to eq(0)
    end

    it 'answers not_found for the logo of a sponsorship the session does not cover' do
      other = FactoryBot.create(:sponsorship, plan: nil)

      expect(connect_call(rpc, create_request(sponsorship_input(asset_file_id: other.asset_file.id)))).to have_attributes(code: 'not_found')
    end

    it 'answers invalid_argument naming input.contact.email for an address that is no email' do
      input = sponsorship_input(asset_file_id: upload_asset_file.id)
      input.contact.email = 'not an email'

      error = connect_call(rpc, create_request(input))
      expect(error).to have_attributes(code: 'invalid_argument')
      expect(violations_of(error)).to eq([['input.contact.email', 'STRING_EMAIL']])
    end

    it 'answers invalid_argument naming input.planId for a plan sold out' do
      plan.update!(capacity: 0)

      error = apply
      expect(error).to have_attributes(code: 'invalid_argument')
      expect(violations_of(error)).to eq([['input.planId', 'UNAVAILABLE']])
    end

    it 'answers invalid_argument naming input.planId for no plan, which the conference does not allow' do
      conference.update!(no_plan_allowed: false)
      expect(violations_of(apply(plan_id: nil))).to eq([['input.planId', 'NO_PLAN_NOT_ALLOWED']])
    end

    it 'answers not_found for a plan of another conference' do
      expect(apply(plan_id: FactoryBot.create(:conference, :full).plans.first.id)).to have_attributes(code: 'not_found')
    end

    it 'answers invalid_argument without the policies agreed to' do
      error = connect_call(rpc, create_request(sponsorship_input(asset_file_id: upload_asset_file.id), policy_agreement: false))
      expect(violations_of(error)).to eq([['policyAgreement', 'POLICY_AGREEMENT_AGREED']])
      expect(Sponsorship.count).to eq(0)
    end

    it 'answers invalid_argument without a logo' do
      error = connect_call(rpc, create_request(sponsorship_input))
      expect(violations_of(error)).to eq([['input', 'SPONSORSHIP_INPUT_ASSET_FILE_ID_REQUIRED']])
    end

    it 'answers failed_precondition for a conference with no form described' do
      asset_file = upload_asset_file
      conference.form_descriptions.destroy_all

      error = connect_call(rpc, create_request(sponsorship_input(asset_file_id: asset_file.id)))
      expect(error).to have_attributes(code: 'failed_precondition')
      expect(Sponsorship.count).to eq(0)
    end

    it 'answers failed_precondition to a contact who has applied already' do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan:)
      sign_in_sponsor(sponsorship.contact.email)

      error = connect_call(rpc, create_request(sponsorship_input(asset_file_id: sponsorship.asset_file.id)))
      expect(error).to have_attributes(code: 'failed_precondition')
    end

    it 'answers conflict when another application from the organization lands first' do
      allow(Sponsorship).to receive(:new).and_wrap_original do |original, *args, **kwargs|
        original.call(*args, **kwargs).tap { allow(it).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique) }
      end

      error = apply
      expect(error).to have_attributes(code: 'aborted')
      expect(problem_type_of(error)).to eq('conflict')
    end

    context 'when applications are closed' do
      before { conference.update!(application_closes_at: 1.hour.ago) }

      it 'answers failed_precondition' do
        expect(apply).to have_attributes(code: 'failed_precondition')
        expect(Sponsorship.count).to eq(0)
      end

      it 'takes the application of staff' do
        sign_in_staff(FactoryBot.create(:staff))
        expect(apply.sponsorship.name).to eq('Contoso')
      end
    end

    context 'when the conference is hidden' do
      before { conference.update!(hidden: true) }

      it 'answers not_found for a wrong invitation code' do
        asset_file = upload_asset_file(invite_code: conference.invite_code)
        error = connect_call(rpc, create_request(sponsorship_input(asset_file_id: asset_file.id), invite_code: 'wrong'))
        expect(error).to have_attributes(code: 'not_found')
      end

      it 'applies with the invitation code' do
        asset_file = upload_asset_file(invite_code: conference.invite_code)
        result = connect_call(rpc, create_request(sponsorship_input(asset_file_id: asset_file.id), invite_code: conference.invite_code))
        expect(result.sponsorship.name).to eq('Contoso')
      end
    end
  end
end
