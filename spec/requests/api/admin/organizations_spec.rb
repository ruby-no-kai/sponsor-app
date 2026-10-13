# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService organizations', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }

  let!(:contoso) { FactoryBot.create(:organization, name: 'Contoso', domain: 'contoso.example.co.invalid', auto_acceptance_disabled: true) }
  let!(:fabrikam) { FactoryBot.create(:organization, name: 'Fabrikam', domain: 'fabrikam.example.invalid') }

  # The factory files a sponsorship under its contact's email domain, so the organization is set
  # after building.
  def create_sponsorship(organization, **attributes)
    FactoryBot.build(:sponsorship, **attributes).tap do |sponsorship|
      sponsorship.organization = organization
      sponsorship.save!
    end
  end

  def input(**fields)
    Rk::SponsorApp::OrganizationInput.new(name: 'Northwind', domain: 'northwind.example.invalid', auto_acceptance_disabled: true, **fields)
  end

  describe 'ListOrganizations' do
    let(:rpc) { connect_method('AdminService', 'ListOrganizations') }
    let(:request_message) { Rk::SponsorApp::AdminServiceListOrganizationsRequest.new }

    before do
      conference = FactoryBot.create(:conference)
      other_conference = FactoryBot.create(:conference)
      create_sponsorship(contoso, conference:, plan: nil)
      create_sponsorship(contoso, conference: other_conference, plan: nil, withdrawn_at: Time.current)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'lists every organization by name, counting its sponsorships, withdrawn ones included' do
        organizations = connect_call(rpc, request_message).organizations

        expect(organizations.map(&:name)).to eq(['Contoso', 'Fabrikam'])
        expect(organizations.first).to eq(Rk::SponsorApp::AdminOrganization.new(
          domain: 'contoso.example.co.invalid',
          name: 'Contoso',
          auto_acceptance_disabled: true,
          affiliation_code: contoso.affiliation_code,
          sponsorship_count: 2,
        ))
        expect(organizations.last).to have_attributes(auto_acceptance_disabled: false, sponsorship_count: 0)
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        expected = connect_call(rpc, request_message)

        expect(connect_call(rpc, request_message, via: :get)).to eq(expected)
        expect(connect_call(rpc, request_message, via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_message, codec: :proto)).to eq(expected)
      end

      it 'counts sponsorships in as many queries however many organizations there are' do
        baseline = query_count { connect_call(rpc, request_message) }
        FactoryBot.create_list(:organization, 3)

        expect(query_count { connect_call(rpc, request_message) }).to eq(baseline)
      end
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, request_message)).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff' do
      sign_in_staff(restricted_staff)

      error = connect_call(rpc, request_message)

      expect(error).to have_attributes(status: 403, code: 'permission_denied')
      expect(problem_type_of(error)).to eq('permission-denied')
    end
  end

  describe 'GetOrganization' do
    let(:rpc) { connect_method('AdminService', 'GetOrganization') }

    def request_for(domain) = Rk::SponsorApp::AdminServiceGetOrganizationRequest.new(domain:)

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'returns the organization by a domain with dots, with an affiliation URL per conference taking applications' do
        FactoryBot.create(:conference, application_opens_at: 1.day.from_now)
        FactoryBot.create(:conference, application_opens_at: 2.days.ago, application_closes_at: 1.day.ago)
        older = FactoryBot.create(:conference, application_opens_at: 2.days.ago)
        newer = FactoryBot.create(:conference, application_opens_at: 1.day.ago, application_closes_at: 1.day.from_now)

        response_message = connect_call(rpc, request_for('contoso.example.co.invalid'))

        expect(response_message.organization).to have_attributes(
          domain: 'contoso.example.co.invalid',
          name: 'Contoso',
          affiliation_code: contoso.affiliation_code,
          sponsorship_count: 0,
        )
        expect(response_message.affiliation_urls.map { [it.conference.slug, it.url] }).to eq([
          [newer.slug, "http://www.example.com/conferences/#{newer.slug}/sponsorship/new?affiliation=#{contoso.affiliation_code}"],
          [older.slug, "http://www.example.com/conferences/#{older.slug}/sponsorship/new?affiliation=#{contoso.affiliation_code}"],
        ])
        expect(response_message.sponsorships).to be_empty
      end

      it 'lists the sponsorships across conferences, latest application first' do
        conference = FactoryBot.create(:conference, name: 'RubyKaigi 2047')
        plan = FactoryBot.create(:plan, conference:, name: 'Platinum')
        withdrawn = create_sponsorship(contoso, conference:, plan: nil, name: 'Contoso 2047', withdrawn_at: Time.current)
        other_conference = FactoryBot.create(:conference, name: 'RubyKaigi 2048')
        other_plan = FactoryBot.create(:plan, conference: other_conference, name: 'Gold')
        latest = create_sponsorship(contoso, conference: other_conference, plan: other_plan, name: 'Contoso KK',
          customization_name: 'Gold Plus', booth_requested: true, booth_assigned: true, accepted_at: Time.current)
        create_sponsorship(fabrikam, conference:, plan:)

        sponsorships = connect_call(rpc, request_for('contoso.example.co.invalid')).sponsorships

        expect(sponsorships.map { it.sponsorship.id }).to eq([latest.id, withdrawn.id])
        expect(sponsorships.first).to have_attributes(plan_name: 'Gold', booth_requested: true)
        expect(sponsorships.first.conference).to have_attributes(slug: other_conference.slug, name: 'RubyKaigi 2048')
        expect(sponsorships.first.sponsorship).to have_attributes(
          name: 'Contoso KK',
          customization_name: 'Gold Plus',
          booth_assigned: true,
          state: :SPONSORSHIP_STATE_ACTIVE,
          organization: Rk::SponsorApp::OrganizationSummary.new(domain: 'contoso.example.co.invalid', name: 'Contoso'),
        )
        expect(sponsorships.last).to have_attributes(has_plan_name?: false, booth_requested: false)
        expect(sponsorships.last.sponsorship).to have_attributes(state: :SPONSORSHIP_STATE_WITHDRAWN, booth_assigned: false)
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        create_sponsorship(contoso, conference: FactoryBot.create(:conference), plan: nil)
        expected = connect_call(rpc, request_for('contoso.example.co.invalid'))

        expect(connect_call(rpc, request_for('contoso.example.co.invalid'), via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for('contoso.example.co.invalid'), via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for('contoso.example.co.invalid'), codec: :proto)).to eq(expected)
      end

      it 'loads the history in as many queries however many sponsorships it lists' do
        create_sponsorship_with_plan = lambda do
          conference = FactoryBot.create(:conference, application_opens_at: 1.day.ago)
          create_sponsorship(contoso, conference:, plan: FactoryBot.create(:plan, conference:))
        end
        create_sponsorship_with_plan.call
        baseline = query_count { connect_call(rpc, request_for('contoso.example.co.invalid')) }
        2.times { create_sponsorship_with_plan.call }

        expect(query_count { connect_call(rpc, request_for('contoso.example.co.invalid')) }).to eq(baseline)
      end

      it 'answers not_found for a domain no organization has' do
        error = connect_call(rpc, request_for('nowhere.example.invalid'))

        expect(error).to have_attributes(status: 404, code: 'not_found')
        expect(problem_type_of(error)).to eq('not-found')
      end

      it 'answers invalid_argument without a domain' do
        expect(violations_of(connect_call(rpc, request_for('')))).to eq([['domain', 'STRING_MIN_LEN']])
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_for(''))).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for('contoso.example.co.invalid'))).to have_attributes(status: 403, code: 'permission_denied')
    end
  end

  describe 'CreateOrganization' do
    let(:rpc) { connect_method('AdminService', 'CreateOrganization') }

    def request_with(input) = Rk::SponsorApp::AdminServiceCreateOrganizationRequest.new(input:)

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'creates the organization with a generated affiliation code' do
        organization = connect_call(rpc, request_with(input)).organization

        stored = Organization.find_by!(domain: 'northwind.example.invalid')
        expect(stored).to have_attributes(name: 'Northwind', auto_acceptance_disabled: true, affiliation_code: be_present)
        expect(organization).to eq(Rk::SponsorApp::AdminOrganization.new(
          domain: 'northwind.example.invalid',
          name: 'Northwind',
          auto_acceptance_disabled: true,
          affiliation_code: stored.affiliation_code,
          sponsorship_count: 0,
        ))
      end

      it 'returns what GetOrganization returns afterwards' do
        created = connect_call(rpc, request_with(input)).organization
        get_request = Rk::SponsorApp::AdminServiceGetOrganizationRequest.new(domain: created.domain)

        expect(connect_call(connect_method('AdminService', 'GetOrganization'), get_request).organization).to eq(created)
      end

      it 'creates over binary protobuf too' do
        expect(connect_call(rpc, request_with(input), codec: :proto).organization.domain).to eq('northwind.example.invalid')
      end

      it 'answers invalid_argument with a violation per broken rule, creating nothing' do
        error = connect_call(rpc, request_with(input(name: ' ', domain: 'Northwind.example.invalid')))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to contain_exactly(
          ['input.name', 'ORGANIZATION_INPUT_NAME_NOT_BLANK'],
          ['input.domain', 'ORGANIZATION_INPUT_DOMAIN_HOSTNAME'],
        )
        expect(Organization.count).to eq(2)
      end

      it 'answers invalid_argument for a domain that is no hostname' do
        ['northwind.example.invalid.', 'north_wind.example.invalid', 'https://northwind.example.invalid', '192.0.2.1'].each do |domain|
          expect(violations_of(connect_call(rpc, request_with(input(domain:)))))
            .to eq([['input.domain', 'ORGANIZATION_INPUT_DOMAIN_HOSTNAME']]), domain
        end
      end

      it 'answers the invalid-record problem on the domain field for a domain another organization has' do
        error = connect_call(rpc, request_with(input(domain: 'fabrikam.example.invalid')))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(problem_type_of(error)).to eq('invalid-record')
        expect(bad_request_of(error).field_violations.map { [it.field, it.reason, it.description] })
          .to eq([['input.domain', 'TAKEN', 'has already been taken']])
        expect(Organization.count).to eq(2)
      end

      it 'answers aborted with the conflict problem when a concurrent save takes the domain after validation' do
        allow(Organization).to receive(:new).and_wrap_original do |new_organization, *args|
          new_organization.call(*args).tap do |organization|
            allow(organization).to receive(:valid?).and_wrap_original do |valid, *valid_args|
              rival = {name: 'Rival', domain: 'northwind.example.invalid', affiliation_code: 'rival'}
              valid.call(*valid_args).tap { Organization.insert!(rival) } # rubocop:disable Rails/SkipsModelValidations
            end
          end
        end

        error = connect_call(rpc, request_with(input))

        expect(error).to have_attributes(status: 409, code: 'aborted')
        expect(problem_type_of(error)).to eq('conflict')
      end

      it 'names the field as a binary request spells it' do
        error = connect_call(rpc, request_with(input(auto_acceptance_disabled: false, name: ' ')), codec: :proto)

        expect(violations_of(error)).to eq([['input.name', 'ORGANIZATION_INPUT_NAME_NOT_BLANK']])
      end

      it 'answers invalid_argument without an input' do
        expect(violations_of(connect_call(rpc, request_with(nil)))).to eq([['input', 'REQUIRED']])
      end

      it 'refuses GET, as creating has side effects' do
        get "#{rpc.path}?#{URI.encode_www_form(connect: 'v1', encoding: 'json', message: request_with(input).to_json)}"

        expect(response).to have_http_status(:method_not_allowed)
      end
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_with(input(name: '')))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff, creating nothing' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input))).to have_attributes(status: 403, code: 'permission_denied')
      expect(Organization.count).to eq(2)
    end
  end

  describe 'UpdateOrganization' do
    let(:rpc) { connect_method('AdminService', 'UpdateOrganization') }

    def request_with(input, domain: 'contoso.example.co.invalid')
      Rk::SponsorApp::AdminServiceUpdateOrganizationRequest.new(domain:, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'replaces every field, the domain included, keeping the affiliation code' do
        create_sponsorship(contoso, conference: FactoryBot.create(:conference), plan: nil)

        organization = connect_call(rpc, request_with(input(auto_acceptance_disabled: false))).organization

        expect(contoso.reload).to have_attributes(name: 'Northwind', domain: 'northwind.example.invalid', auto_acceptance_disabled: false)
        expect(organization).to eq(Rk::SponsorApp::AdminOrganization.new(
          domain: 'northwind.example.invalid',
          name: 'Northwind',
          auto_acceptance_disabled: false,
          affiliation_code: contoso.affiliation_code,
          sponsorship_count: 1,
        ))
      end

      it 'keeps its own domain' do
        connect_call(rpc, request_with(input(domain: 'contoso.example.co.invalid')))

        expect(contoso.reload).to have_attributes(name: 'Northwind', domain: 'contoso.example.co.invalid')
      end

      it 'updates over binary protobuf too' do
        expect(connect_call(rpc, request_with(input), codec: :proto).organization.name).to eq('Northwind')
      end

      it 'answers not_found for a domain no organization has' do
        expect(connect_call(rpc, request_with(input, domain: 'nowhere.example.invalid'))).to have_attributes(code: 'not_found')
        expect(Organization.find_by(domain: 'northwind.example.invalid')).to be_nil
      end

      it 'answers the invalid-record problem for a domain another organization has, leaving it as it was' do
        error = connect_call(rpc, request_with(input(domain: 'fabrikam.example.invalid')))

        expect(violations_of(error)).to eq([['input.domain', 'TAKEN']])
        expect(contoso.reload).to have_attributes(name: 'Contoso', domain: 'contoso.example.co.invalid')
      end

      it 'leaves the organization as it was on a broken rule' do
        error = connect_call(rpc, request_with(input(domain: 'Contoso.example.co.invalid')))

        expect(violations_of(error)).to eq([['input.domain', 'ORGANIZATION_INPUT_DOMAIN_HOSTNAME']])
        expect(contoso.reload.name).to eq('Contoso')
      end

      it 'answers invalid_argument without a domain' do
        expect(violations_of(connect_call(rpc, request_with(input, domain: '')))).to eq([['domain', 'STRING_MIN_LEN']])
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_with(input(name: ''), domain: ''))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff, leaving the organization as it was' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input))).to have_attributes(status: 403, code: 'permission_denied')
      expect(contoso.reload.name).to eq('Contoso')
    end
  end
end
