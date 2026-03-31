# frozen_string_literal: true

class ExpenseReportResource
  include Alba::Resource

  attributes :id, :status, :total_amount, :total_tax_amount, :revision, :created_at, :updated_at

  has_many :line_items, resource: ExpenseLineItemResource, key: 'line_items'

  attribute :files do |report|
    report.sponsorship.expense_files.map do |file|
      ExpenseFileResource.new(file).to_h
    end
  end

  attribute :latest_review do |report|
    review = report.latest_review
    ExpenseReportReviewResource.new(review).to_h if review
  end
end
