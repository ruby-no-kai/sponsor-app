# typed: strict
# frozen_string_literal: true

module Admin
  class InvoicesController < Admin::ApplicationController
    before_action :set_conference

    #: () -> void
    def index
      invoice_csv = prepare_invoice_inputs

      respond_to do |format|
        format.html do
          @invoice_headers = invoice_csv.headers #: Array[String]?
          @invoice_rows = invoice_csv.rows #: Array[Array[String | Integer | nil]]?
          @excluded_invoice_rows = invoice_csv.excluded_rows #: Array[Array[String | Integer | nil]]?
        end
        format.csv { export_csv(invoice_csv) }
      end
    end

    #: () -> MoneyForwardInvoiceCsv
    private def prepare_invoice_inputs
      invoice_date = params[:invoice_date].present? ? parse_date(params[:invoice_date].to_s) : Time.zone.today
      delivery_date = parse_date(params[:delivery_date].to_s) if params[:delivery_date].present?
      starting_invoice_number = [params[:starting_invoice_number].to_s.to_i, 1].max
      filter_params = invoice_filter_params
      invoice_filter = InvoiceSponsorshipFilter.new(
        conference:,
        filters: filter_params[:filters],
        locales: filter_params[:locales],
        plan_ids: filter_params[:plan_ids],
        customization_filter: filter_params[:customization_filter],
      )
      @invoice_date = invoice_date #: Date?
      @delivery_date = delivery_date #: Date?
      @starting_invoice_number = starting_invoice_number #: Integer?
      @invoice_filter = invoice_filter #: InvoiceSponsorshipFilter?

      MoneyForwardInvoiceCsv.new(
        conference:,
        sponsorships: invoice_filter.sponsorships,
        invoice_date:,
        delivery_date:,
        starting_invoice_number:,
      )
    end

    #: (String) -> Date
    private def parse_date(value)
      Date.parse(value)
    rescue Date::Error
      raise ActionController::BadRequest, 'Invalid invoice or delivery date.'
    end

    #: (MoneyForwardInvoiceCsv) -> void
    private def export_csv(invoice_csv)
      if @delivery_date.nil?
        redirect_to conference_invoices_path(conference), alert: 'Delivery date is required.'
      elsif invoice_csv.exportable?
        send_data(invoice_csv.to_csv, filename: "#{conference.name.underscore.gsub(" ", "_")}_invoices.csv", type: 'text/csv')
      else
        redirect_to conference_invoices_path(conference, request.query_parameters), alert: 'There are no invoices to export.'
      end
    end

    #: () -> void
    private def set_conference
      @conference = Conference.find_by!(slug: params[:conference_slug]) #: Conference?
      check_staff_conference_authorization!(conference)
    end

    #: () -> Conference
    private def conference = Must.because(@conference) { "set_conference runs before every action" }

    #: () -> ActionController::Parameters
    private def invoice_filter_params
      params.permit(:filters, :customization_filter, locales: [], plan_ids: [])
    end
  end
end
