# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Invoices", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:csv_rows) { CSV.parse(response.body, headers: true) }
  let(:invoice_rows) { csv_rows.select { |row| row['行形式'] == '請求書' } }
  let(:item_rows) { csv_rows.select { |row| row['行形式'] == '品目' } }

  let(:conference) { FactoryBot.create(:conference, name: 'RubyKaigi YYYY') }
  let(:ruby_plan) { FactoryBot.create(:plan, conference:, name: 'Ruby', price: 300_000, price_text: '30万円') }
  let(:gold_plan) { FactoryBot.create(:plan, conference:, name: 'Gold', price: 200_000, price_text: '20万円') }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }
  let(:standard_ja_sponsorship) do
    FactoryBot.create(:sponsorship, conference:, plan: ruby_plan, locale: 'ja', accepted_at: Time.current)
  end
  let!(:custom_en_sponsorship) do
    FactoryBot.create(:sponsorship, conference:, plan: ruby_plan, locale: 'en', customization: true, customization_name: 'Custom Ruby', accepted_at: Time.current)
  end
  let(:standard_en_sponsorship) do
    FactoryBot.create(:sponsorship, conference:, plan: gold_plan, locale: 'en', accepted_at: Time.current)
  end

  context 'without staff authentication' do
    it 'redirects to staff login' do
      get conference_invoices_path(conference)

      expect(response).to redirect_to(new_session_path(back_to: conference_invoices_path(conference)))
    end
  end

  context 'with staff authentication' do
    before do
      standard_ja_sponsorship
      standard_en_sponsorship
      get claim_user_session_path(session_token.handle)
    end

    it 'renders the HTML preview without a delivery date' do
      get conference_invoices_path(conference)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Invoices included in CSV export')
    end

    it 'exports every sponsorship by default with the existing filename' do
      travel_to Time.zone.local(2026, 8, 16, 12) do
        get conference_invoices_path(conference, format: :csv), params: {delivery_date: '2026-10-03'}
      end

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/csv')
      expect(response.headers['Content-Disposition']).to include('ruby_kaigi_yyyy_invoices.csv')
      expect(invoice_rows.size).to eq(3)
      expect(invoice_rows.first['請求日']).to eq('2026/08/16')
    end

    it 'passes the selected locale, plan, and customization to the export' do
      get conference_invoices_path(conference, format: :csv), params: {
        filters: 1,
        locales: ['en'],
        plan_ids: [ruby_plan.id],
        customization_filter: 'with',
        delivery_date: '2026-10-03',
      }

      expect(response).to have_http_status(:ok)
      expect(invoice_rows.size).to eq(1)
      expect(invoice_rows.first['取引先名称']).to eq(custom_en_sponsorship.billing_contact.organization)
    end

    it 'passes the specified dates and starting number to the export' do
      get conference_invoices_path(conference, format: :csv), params: {
        invoice_date: '2026-08-16', delivery_date: '2026-10-03', starting_invoice_number: 42,
      }

      expect(response).to have_http_status(:ok)
      expect(invoice_rows.first.values_at('請求日', '請求書番号')).to eq(['2026/08/16', '20260816-042'])
      expect(item_rows.first['納品日']).to eq('2026/10/03')
    end

    it 'rejects an invalid invoice date in the preview' do
      get conference_invoices_path(conference), params: {invoice_date: 'not-a-date'}

      expect(response).to have_http_status(:bad_request)
    end

    it 'rejects an invalid delivery date in the export' do
      get conference_invoices_path(conference, format: :csv), params: {delivery_date: '2026-02-30'}

      expect(response).to have_http_status(:bad_request)
    end

    it 'clamps a nonpositive starting number to one' do
      get conference_invoices_path(conference, format: :csv), params: {
        invoice_date: '2026-08-16', delivery_date: '2026-10-03', starting_invoice_number: -2,
      }

      expect(invoice_rows.first['請求書番号']).to eq('20260816-001')
    end

    it 'does not export CSV without a delivery date' do
      get conference_invoices_path(conference, format: :csv)

      expect(response).to redirect_to(conference_invoices_path(conference))
      expect(flash[:alert]).to eq('Delivery date is required.')
    end

    context 'with a separate billing contact' do
      before do
        FactoryBot.create(:contact, sponsorship: custom_en_sponsorship, kind: :billing,
          organization: 'Billing Company', unit: 'Accounting', name: 'Billing Contact')
      end

      it 'exports the billing contact instead of the primary contact' do
        get conference_invoices_path(conference, format: :csv), params: {
          filters: 1,
          locales: ['en'],
          plan_ids: [ruby_plan.id],
          customization_filter: 'with',
          delivery_date: '2026-10-03',
        }

        expect(response).to have_http_status(:ok)
        expect(invoice_rows.size).to eq(1)
        expect(invoice_rows.first.values_at('取引先名称', '取引先部署', '取引先担当者氏名')).to eq(['Billing Company', 'Accounting', 'Billing Contact'])
      end
    end

    context 'with no selections' do
      let(:filter_params) { {filters: '1', invoice_date: '2026-08-16', delivery_date: '2026-10-03', starting_invoice_number: '42'} }

      it 'renders an empty HTML preview' do
        get conference_invoices_path(conference), params: filter_params

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('There are no invoices to export.')
      end

      it 'preserves query parameters when redirecting an empty export' do
        get conference_invoices_path(conference, format: :csv), params: filter_params

        expect(response).to redirect_to(conference_invoices_path(conference, filter_params))
        expect(flash[:alert]).to eq('There are no invoices to export.')
      end

      it 'checks delivery date before checking for exportable invoices' do
        get conference_invoices_path(conference, format: :csv), params: {filters: '1'}

        expect(response).to redirect_to(conference_invoices_path(conference))
        expect(flash[:alert]).to eq('Delivery date is required.')
      end
    end

    context 'with a negative invoice' do
      let(:filter_params) do
        {filters: '1', locales: ['en'], plan_ids: [ruby_plan.id.to_s], customization_filter: 'with', delivery_date: '2026-10-03'}
      end

      before do
        ExpenseReport.create!(sponsorship: custom_en_sponsorship, status: 'approved', total_amount: 400_000)
      end

      it 'renders excluded invoices in the HTML preview' do
        get conference_invoices_path(conference), params: filter_params

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Excluded invoices (negative subtotal)')
        expect(response.body).to include('There are no invoices to export.')
      end

      it 'redirects when the export contains only excluded invoices' do
        get conference_invoices_path(conference, format: :csv), params: filter_params

        expect(response).to redirect_to(conference_invoices_path(conference, filter_params))
        expect(flash[:alert]).to eq('There are no invoices to export.')
      end
    end

    context 'with restricted staff access' do
      let(:staff) { FactoryBot.create(:staff, restricted_repos: ['kaigionrails/allowed']) }

      it 'forbids access to a conference outside the staff permissions' do
        get conference_invoices_path(conference)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
