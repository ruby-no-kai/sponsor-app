# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Errors do
  describe Errors::ApiError do
    let(:prefix) { 'https://sponsorships.rubykaigi.org/problems/' }

    {
      Errors::Unauthenticated => ['unauthenticated', 401, 'Unauthenticated'],
      Errors::PermissionDenied => ['permission-denied', 403, 'Permission Denied'],
      Errors::NotFound => ['not-found', 404, 'Not Found'],
      Errors::Conflict => ['conflict', 409, 'Conflict'],
      Errors::FailedPrecondition => ['failed-precondition', 412, 'Failed Precondition'],
      Errors::Internal => ['internal', 500, 'Internal Error'],
    }.each do |klass, (identifier, status, title)|
      it "renders #{klass} as #{identifier} with #{status}" do
        problem = klass.new(detail: 'occurrence').to_problem

        expect(problem).to have_attributes(type: "#{prefix}#{identifier}", status:, title:, detail: 'occurrence')
      end
    end

    it 'raises when a class declares a value the enum does not define' do
      expect { Class.new(described_class) { problem_type :PROBLEM_TYPE_NONEXISTENT } }
        .to raise_error(Protobufable::Error, /unknown or unannotated value PROBLEM_TYPE_NONEXISTENT/)
    end

    it 'raises when a class declares the unannotated value' do
      expect { Class.new(described_class) { problem_type :PROBLEM_TYPE_UNSPECIFIED } }.to raise_error(Protobufable::Error)
    end

    describe 'the ProblemType catalogue' do
      let(:catalogue) { described_class.problem_type_catalogue }

      it 'annotates every value but the unspecified one' do
        values = Rk::SponsorApp::ProblemType.descriptor.map { |name, _number| name }

        expect(catalogue.keys).to match_array(values - [:PROBLEM_TYPE_UNSPECIFIED])
      end

      it 'gives every identifier one status' do
        catalogue.values.group_by(&:uri).each do |uri, entries|
          expect(entries.map(&:http_status).uniq).to eq([entries.first.http_status]), "#{uri} has several statuses"
        end
      end

      it 'titles every identifier in every locale' do
        catalogue.values.map(&:uri).uniq.each do |uri|
          I18n.available_locales.each do |locale|
            expect(I18n.exists?("problem_details.titles.#{uri.tr('-', '_')}", locale)).to be(true), "#{uri} has no #{locale} title"
          end
        end
      end
    end
  end

  describe Errors::InvalidRecord do
    let(:record) do
      FormDescription.new.tap do |form_description|
        form_description.errors.add(:fallback_options, 'options[0].value: value is required')
        form_description.errors.add(:locale, :blank)
        form_description.errors.add(:conference, :blank)
        form_description.errors.add(:base, 'Something is off')
      end
    end

    def violations(error)
      error.problem_information.grep(Google::Rpc::BadRequest).sole.field_violations.map do |violation|
        [violation.field, violation.reason, violation.description]
      end
    end

    it 'is the invalid-record problem, detailing every error' do
      problem = described_class.new(record:).to_problem

      expect(problem).to have_attributes(
        type: 'https://sponsorships.rubykaigi.org/problems/invalid-record',
        status: 422,
        title: 'Invalid Record',
        detail: "Fallback Options options[0].value: value is required; Locale can't be blank; " \
          "Conference can't be blank; Something is off",
      )
    end

    it 'names the Input field an attribute maps to, as ProtoJSON spells it' do
      error = described_class.new(record:, input_class: Rk::SponsorApp::FormDescriptionInput, field_prefix: 'input', json_names: true)

      expect(violations(error)).to eq([
        ['input.fallbackOptions', 'INVALID_VALUE', 'options[0].value: value is required'],
        ['input.locale', 'BLANK', "can't be blank"],
        ['', 'BLANK', "Conference can't be blank"],
        ['', 'INVALID_VALUE', 'Something is off'],
      ])
    end

    it 'names fields as the binary encoding spells them' do
      error = described_class.new(record:, input_class: Rk::SponsorApp::FormDescriptionInput, field_prefix: 'input')

      expect(violations(error).map(&:first)).to eq(['input.fallback_options', 'input.locale', '', ''])
    end

    it "names a plan attribute's PlanInput field" do
      plan = Plan.new.tap { it.errors.add(:price_text, :invalid) }
      error = described_class.new(record: plan, input_class: Rk::SponsorApp::PlanInput, field_prefix: 'input', json_names: true)

      expect(violations(error)).to eq([['input.priceText', 'INVALID', 'is invalid']])
    end

    it 'names the ID field of an association the Input names by ID' do
      sponsorship = Sponsorship.new.tap do |record|
        record.errors.add(:plan, :unavailable)
        record.errors.add(:asset_file, :blank)
        record.errors.add(:organization, :taken)
      end
      error = described_class.new(record: sponsorship, input_class: Rk::SponsorApp::SponsorshipInput, field_prefix: 'input', json_names: true)

      expect(violations(error).map(&:first)).to eq(['input.planId', 'input.assetFileId', ''])
    end

    it 'names no field without an Input' do
      expect(violations(described_class.new(record:)).map(&:first)).to all(eq(''))
    end

    describe 'an autosaved association' do
      # As autosave imports an associated record's errors.
      def import(sponsorship, association, associated, attribute, type)
        sponsorship.errors.import(ActiveModel::Error.new(associated, attribute, type), attribute: :"#{association}.#{attribute}")
      end

      let(:record) do
        Sponsorship.new.tap do |sponsorship|
          import(sponsorship, :contact, Contact.new, :email_cc, :invalid)
          import(sponsorship, :alternate_billing_contact, Contact.new, :email, :blank)
          import(sponsorship, :alternate_billing_contact, Contact.new, :email_cc, :invalid)
          import(sponsorship, :billing_request, SponsorshipRequest.new, :body, :blank)
        end
      end

      it "names the field within the Input's field of the association's name" do
        error = described_class.new(record:, input_class: Rk::SponsorApp::AdminSponsorshipInput, field_prefix: 'input', json_names: true)

        expect(violations(error)).to eq([
          ['input.contact.emailCc', 'INVALID', 'is invalid'],
          ['input.alternateBillingContact.email', 'BLANK', "can't be blank"],
          ['', 'INVALID', 'Alternate billing contact email cc is invalid'],
          ['', 'BLANK', "Additional Note for Billing can't be blank"],
        ])
      end

      it 'names fields as the binary encoding spells them' do
        error = described_class.new(record:, input_class: Rk::SponsorApp::AdminSponsorshipInput, field_prefix: 'input')

        expect(violations(error).map(&:first)).to eq(['input.contact.email_cc', 'input.alternate_billing_contact.email', '', ''])
      end
    end
  end
end
