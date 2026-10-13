# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService exhibitions', type: :request do
  let(:create_rpc) { connect_method('SponsorService', 'CreateExhibition') }
  let(:update_rpc) { connect_method('SponsorService', 'UpdateExhibition') }
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first, booth_assigned: true) }

  def create_request(description = 'Ruby on a bench', slug: conference.slug)
    Rk::SponsorApp::SponsorServiceCreateExhibitionRequest.new(
      conference_slug: slug,
      input: Rk::SponsorApp::ExhibitionInput.new(description:),
    )
  end

  def update_request(description = 'Ruby on two benches')
    Rk::SponsorApp::SponsorServiceUpdateExhibitionRequest.new(
      conference_slug: conference.slug,
      input: Rk::SponsorApp::ExhibitionInput.new(description:),
    )
  end

  before { allow(SlackWebhookJob).to receive(:perform_later) }

  it 'answers unauthenticated without a sponsor session' do
    expect(connect_call(create_rpc, create_request)).to have_attributes(code: 'unauthenticated')
    expect(connect_call(update_rpc, update_request)).to have_attributes(code: 'unauthenticated')
  end

  context 'with a sponsor session' do
    before { sign_in_sponsor(sponsorship.contact.email) }

    describe 'CreateExhibition' do
      it 'saves the booth details, notifies Slack and records a history without staff' do
        result = connect_call(create_rpc, create_request)

        expect(result.exhibition.description).to eq('Ruby on a bench')
        exhibition = sponsorship.reload.exhibition
        expect(exhibition.description).to eq('Ruby on a bench')
        expect(exhibition.editing_histories.sole).to have_attributes(staff: nil)
        expect(SlackWebhookJob).to have_received(:perform_later)
          .with({text: a_string_including('booth details submitted by sponsor', sponsorship.name)}, hook_name: 'feed')
      end

      it 'answers failed_precondition without a booth assigned' do
        sponsorship.update!(booth_assigned: false)

        expect(connect_call(create_rpc, create_request)).to have_attributes(code: 'failed_precondition')
        expect(Exhibition.count).to eq(0)
        expect(SlackWebhookJob).not_to have_received(:perform_later)
      end

      it 'answers aborted when the sponsorship has booth details already' do
        Exhibition.create!(sponsorship:, description: 'Existing')

        error = connect_call(create_rpc, create_request)

        expect(error).to have_attributes(code: 'aborted')
        expect(problem_type_of(error)).to eq('conflict')
        expect(Exhibition.where(sponsorship:).count).to eq(1)
      end

      it 'answers invalid_argument for a blank description' do
        error = connect_call(create_rpc, create_request('  '))

        expect(error).to have_attributes(code: 'invalid_argument')
        expect(violations_of(error)).to eq([['input.description', 'EXHIBITION_INPUT_DESCRIPTION_NOT_BLANK']])
      end

      it 'answers not_found for a conference the contact does not sponsor' do
        other = FactoryBot.create(:conference, :full)

        expect(connect_call(create_rpc, create_request(slug: other.slug))).to have_attributes(code: 'not_found')
      end
    end

    describe 'UpdateExhibition' do
      let!(:exhibition) { Exhibition.create!(sponsorship:, description: 'Before') }

      it 'replaces the description, notifies Slack and records a history without staff' do
        result = connect_call(update_rpc, update_request)

        expect(result.exhibition.description).to eq('Ruby on two benches')
        expect(exhibition.reload.description).to eq('Ruby on two benches')
        expect(exhibition.editing_histories.order(:id).last).to have_attributes(staff: nil)
        expect(SlackWebhookJob).to have_received(:perform_later)
          .with({text: a_string_including('booth details edited by sponsor')}, hook_name: 'feed')
      end

      it 'answers not_found without booth details' do
        exhibition.destroy!

        expect(connect_call(update_rpc, update_request)).to have_attributes(code: 'not_found')
      end

      it 'answers failed_precondition without a booth assigned' do
        sponsorship.update!(booth_assigned: false)

        expect(connect_call(update_rpc, update_request)).to have_attributes(code: 'failed_precondition')
        expect(exhibition.reload.description).to eq('Before')
      end

      it 'answers invalid_argument for a blank description' do
        expect(connect_call(update_rpc, update_request(''))).to have_attributes(code: 'invalid_argument')
      end
    end
  end
end
