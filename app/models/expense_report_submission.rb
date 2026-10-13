# typed: strict
# frozen_string_literal: true

class ExpenseReportSubmission < ApplicationRecord
  belongs_to :expense_report
  has_one :review, class_name: 'ExpenseReportReview', dependent: :destroy

  attribute :data, Protobufable::JsonType.new(Rk::SponsorApp::Internal::ExpenseReportSnapshot, preserve_proto_fieldnames: true),
    default: -> { Rk::SponsorApp::Internal::ExpenseReportSnapshot.new }

  #: () -> bool
  def reviewed?
    review.present?
  end
end
