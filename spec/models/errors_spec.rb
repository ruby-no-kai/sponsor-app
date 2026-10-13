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
end
