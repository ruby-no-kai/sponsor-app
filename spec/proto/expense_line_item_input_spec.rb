# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ExpenseLineItemInput rules' do # rubocop:disable RSpec/DescribeClass
  def input_accepts?(attribute, value)
    field = attribute.to_s
    Protovalidate.collect_violations(Rk::SponsorApp::ExpenseLineItemInput.new(title: 'Venue', attribute => value))
      .none? { it.field_path == field }
  end

  def line_item_accepts?(attribute, value)
    FactoryBot.build(:expense_line_item, tax_rate: nil, attribute => value).tap(&:validate).errors[attribute].empty?
  end

  # ExpenseLineItem keeps these checks for the HAML editor, so the two must agree on these samples.
  {
    amount: ['0', '12000', '12000.5', '12000.50', '9999999999.99', '10000000000', '-1', 'abc', '1,000', ''],
    tax_amount: ['0', '1200', '1200.25', '9999999999', '10000000000', '-0.01', 'abc'],
  }.each do |attribute, samples|
    samples.each do |value|
      it "judges #{attribute} #{value.inspect} as ExpenseLineItem does" do
        expect(input_accepts?(attribute, value)).to eq(line_item_accepts?(attribute, value))
      end
    end
  end

  # The column keeps two decimal places and rounds the rest, which the Input refuses instead.
  ['1.234', '1e3', ' 12'].each do |value|
    it "refuses amount #{value.inspect}, which ExpenseLineItem takes" do
      expect(input_accepts?(:amount, value)).to be(false)
      expect(line_item_accepts?(:amount, value)).to be(true)
    end
  end

  it 'takes each configured tax rate as the calculation spells it' do
    ExpenseReportCalculationResource.new(FactoryBot.build(:sponsorship, plan: nil)).as_protobuf.tax_rates.each do |rate|
      expect(input_accepts?(:tax_rate, rate)).to be(true)
    end
  end
end
