# typed: strict
# frozen_string_literal: true

require 'csv'

# Money Forward invoice CSV import format with vertically arranged line items (縦並び).
# https://biz.moneyforward.com/support/invoice/guide/document02/do019.html
class MoneyForwardInvoiceCsv
  # Required csv_type value for this invoice CSV format; Money Forward requires it to remain unchanged.
  CSV_TYPE = 40_101 #: Integer
  NOTE = '払込手数料は、御社のご負担とさせていただきます。' #: String

  COLUMNS = {
    csv_type: 'csv_type(変更不可)',
    row_type: '行形式',
    customer_name: '取引先名称',
    subject: '件名',
    billing_date: '請求日',
    due_date: 'お支払期限',
    invoice_number: '請求書番号',
    sales_date: '売上計上日',
    memo: 'メモ',
    tag: 'タグ',
    subtotal: '小計',
    tax: '消費税',
    total: '合計金額',
    customer_title: '取引先敬称',
    customer_postal_code: '取引先郵便番号',
    customer_prefecture: '取引先都道府県',
    customer_address1: '取引先住所1',
    customer_address2: '取引先住所2',
    customer_department: '取引先部署',
    customer_contact_title: '取引先担当者役職',
    customer_contact_name: '取引先担当者氏名',
    issuer_contact_name: '自社担当者氏名',
    note: '備考',
    bank_account: '振込先',
    payment_status: '入金ステータス',
    email_status: 'メール送信ステータス',
    postal_status: '郵送ステータス',
    download_status: 'ダウンロードステータス',
    delivery_date: '納品日',
    item_name: '品名',
    item_code: '品目コード',
    unit_price: '単価',
    quantity: '数量',
    unit: '単位',
    delivery_number: '納品書番号',
    detail: '詳細',
    amount: '金額',
    item_tax_rate: '品目消費税率',
  }.freeze #: Hash[Symbol, String]

  #: (conference: Conference, sponsorships: Enumerable[Sponsorship], invoice_date: Date, delivery_date: Date?, ?starting_invoice_number: Integer) -> void
  def initialize(conference:, sponsorships:, invoice_date:, delivery_date:, starting_invoice_number: 1)
    @conference = conference #: Conference
    @sponsorships = sponsorships #: Enumerable[Sponsorship]
    @invoice_date = invoice_date #: Date
    @delivery_date = delivery_date #: Date?
    @starting_invoice_number = starting_invoice_number #: Integer
    @rows = nil #: Array[Array[String | Integer | nil]]?
    @excluded_rows = nil #: Array[Array[String | Integer | nil]]?
    @invoices_by_sign = nil #: [Array[SponsorshipInvoice], Array[SponsorshipInvoice]]?
  end

  #: () -> Array[String]
  def headers
    COLUMNS.values
  end

  #: () -> Array[Array[String | Integer | nil]]
  def rows
    @rows ||= exportable_invoices.each_with_index.flat_map do |invoice, index|
      invoice_rows(invoice, starting_invoice_number + index)
    end
  end

  #: () -> Array[Array[String | Integer | nil]]
  def excluded_rows
    @excluded_rows ||= excluded_invoices.flat_map { |invoice| invoice_rows(invoice, nil) }
  end

  #: () -> bool
  def exportable?
    exportable_invoices.any?
  end

  #: () -> String
  def to_csv
    CSV.generate(row_sep: "\r\n") do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
  end

  #: () -> Conference
  private def conference = @conference

  #: () -> Enumerable[Sponsorship]
  private def sponsorships = @sponsorships

  #: () -> Date
  private def invoice_date = @invoice_date

  #: () -> Date?
  private def delivery_date = @delivery_date

  #: () -> Integer
  private def starting_invoice_number = @starting_invoice_number

  #: () -> Array[SponsorshipInvoice]
  private def exportable_invoices
    invoices_by_sign.fetch(0)
  end

  #: () -> Array[SponsorshipInvoice]
  private def excluded_invoices
    invoices_by_sign.fetch(1)
  end

  #: () -> [Array[SponsorshipInvoice], Array[SponsorshipInvoice]]
  private def invoices_by_sign
    @invoices_by_sign ||= sponsorships.map { |sponsorship| SponsorshipInvoice.new(sponsorship:) }.partition(&:exportable?)
  end

  #: (SponsorshipInvoice, Integer?) -> Array[Array[String | Integer | nil]]
  private def invoice_rows(invoice, invoice_number)
    rows = [invoice_row(invoice, invoice_number), plan_item_row(invoice)]
    rows << booth_item_row(invoice) if invoice.sponsorship.booth_assigned
    rows << custom_sponsorship_item_row(invoice) if invoice.approved_expense_amount.positive?
    rows
  end

  #: (SponsorshipInvoice, Integer?) -> Array[String | Integer | nil]
  private def invoice_row(invoice, invoice_number)
    sponsorship = invoice.sponsorship
    contact = Must.expect(sponsorship.billing_contact)

    build_row(
      csv_type: CSV_TYPE,
      row_type: '請求書',
      customer_name: contact.organization,
      subject: "#{conference.name} 協賛のご請求",
      billing_date: formatted_invoice_date,
      due_date: (invoice_date + 1.month).end_of_month.strftime('%Y/%m/%d'),
      invoice_number: formatted_invoice_number(invoice_number),
      sales_date: formatted_invoice_date,
      memo: Must.expect(sponsorship.plan).name,
      subtotal: invoice.subtotal,
      tax: invoice.tax,
      total: invoice.total,
      customer_title: '御中',
      customer_department: contact.unit,
      customer_contact_title: '',
      customer_contact_name: contact.name,
      note: NOTE,
    )
  end

  #: (SponsorshipInvoice) -> Array[String | Integer | nil]
  private def plan_item_row(invoice)
    item_row("#{conference.name} 協賛費用 (#{Must.expect(invoice.sponsorship.plan).name})", invoice.plan_amount)
  end

  #: (SponsorshipInvoice) -> Array[String | Integer | nil]
  private def booth_item_row(invoice)
    item_row("#{conference.name} 協賛費用 (ブース出展)", invoice.booth_amount)
  end

  #: (SponsorshipInvoice) -> Array[String | Integer | nil]
  private def custom_sponsorship_item_row(invoice)
    item_row('カスタムスポンサー費用分', -invoice.approved_expense_amount)
  end

  #: (String, Integer) -> Array[String | Integer | nil]
  private def item_row(name, price)
    build_row(
      csv_type: CSV_TYPE,
      row_type: '品目',
      delivery_date: formatted_delivery_date,
      item_name: name,
      unit_price: price,
      quantity: 1,
      amount: price,
      item_tax_rate: tax_rate_label,
    )
  end

  #: () -> String
  private def tax_rate_label
    "#{(SponsorshipInvoice::TAX_RATE * 100).to_i}%"
  end

  #: (Hash[Symbol, String | Integer | nil]) -> Array[String | Integer | nil]
  private def build_row(values)
    COLUMNS.keys.map { |column| values[column] }
  end

  #: () -> String
  private def formatted_invoice_date
    invoice_date.strftime('%Y/%m/%d')
  end

  #: () -> String?
  private def formatted_delivery_date
    delivery_date&.strftime('%Y/%m/%d')
  end

  #: (Integer?) -> String?
  private def formatted_invoice_number(invoice_number)
    "#{invoice_date.strftime("%Y%m%d")}-#{format("%03d", invoice_number)}" if invoice_number
  end
end
