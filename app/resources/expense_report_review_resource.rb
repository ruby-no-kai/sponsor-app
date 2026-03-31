# frozen_string_literal: true

class ExpenseReportReviewResource
  include Alba::Resource

  attributes :action, :comment, :created_at
end
