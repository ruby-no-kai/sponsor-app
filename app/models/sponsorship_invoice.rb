# typed: strict
# frozen_string_literal: true

class SponsorshipInvoice
  TAX_RATE = BigDecimal('0.1') #: BigDecimal

  #: Sponsorship
  attr_reader :sponsorship

  #: (sponsorship: Sponsorship) -> void
  def initialize(sponsorship:)
    @sponsorship = sponsorship #: Sponsorship
  end

  #: () -> Integer
  def plan_amount
    amount_in_yen(Must.expect(sponsorship.plan).price)
  end

  #: () -> Integer
  def booth_amount
    return 0 unless sponsorship.booth_assigned

    amount_in_yen(Must.expect(sponsorship.plan).price_booth)
  end

  #: () -> Integer
  def approved_expense_amount
    report = sponsorship.expense_report
    return 0 unless sponsorship.customization && report && report.status == 'approved'

    amount_in_yen(report.total_amount)
  end

  #: () -> Integer
  def subtotal
    plan_amount + booth_amount - approved_expense_amount
  end

  #: () -> Integer
  def tax
    (subtotal * TAX_RATE).floor
  end

  #: () -> Integer
  def total
    subtotal + tax
  end

  #: () -> bool
  def exportable?
    subtotal >= 0
  end

  #: (BigDecimal | Integer) -> Integer
  private def amount_in_yen(amount)
    amount.to_d.round(0, BigDecimal::ROUND_HALF_UP).to_i
  end
end
