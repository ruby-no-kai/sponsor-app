# typed: strict
# frozen_string_literal: true

module FormDescriptionsHelper
  # Pretty-printed with the .proto's field names, for staff to read and edit.
  #: (Rk::SponsorApp::Internal::FallbackOptions) -> String
  def fallback_options_json(fallback_options)
    JSON.pretty_generate(JSON.parse(
      Rk::SponsorApp::Internal::FallbackOptions.encode_json(fallback_options, preserve_proto_fieldnames: true),
    ))
  end

  # The data attributes app/javascript/user_sponsorships_form.ts reads off each option, whose
  # conditions it expects with snake_case keys and without the unset ones.
  #: (Rk::SponsorApp::Internal::FallbackOption) -> Hash[Symbol, String]
  def fallback_option_data(option)
    data = {} #: Hash[Symbol, String]
    unless option.conditions.empty?
      data[:conditions] = JSON.generate(option.conditions.map do |condition|
        JSON.parse(Rk::SponsorApp::Internal::FallbackOption::Condition.encode_json(condition, preserve_proto_fieldnames: true))
      end)
    end
    data[:priority_human] = JSON.generate(option.priority_human.to_a) unless option.priority_human.empty?
    data
  end
end
