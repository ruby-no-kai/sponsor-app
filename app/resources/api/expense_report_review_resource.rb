# typed: strict
# frozen_string_literal: true

module Api
  class ExpenseReportReviewResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::ExpenseReportReview do
      attribute(:action) { |review| :"ACTION_#{review.action.upcase}" }
      attributes :comment, if: proc { |review| !review.comment.nil? }
      attributes created_at: :timestamp
    end
  end
end
