# typed: strict

# Tapioca types a Protobufable::JsonType column untyped, as the type declares no signature it can read.
class ExpenseReportSubmission
  sig { returns(Rk::SponsorApp::Internal::ExpenseReportSnapshot) }
  def data; end
end
