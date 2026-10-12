# typed: strict

# Tapioca types a Protobufable::JsonType column untyped, as the type declares no signature it can read.
class FormDescription
  sig { returns(Rk::SponsorApp::Internal::FallbackOptions) }
  def fallback_options; end
end
