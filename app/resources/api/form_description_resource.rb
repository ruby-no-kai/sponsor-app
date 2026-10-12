# typed: strict
# frozen_string_literal: true

module Api
  class FormDescriptionResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::FormDescription do
      attributes :locale

      # Most text columns are nullable, which the message publishes as empty.
      FormDescription::MARKDOWN_FIELDS.each do |field|
        attribute(field) { |form_description| form_description[field].to_s }
        attribute(:"#{field}_html") { |form_description| form_description[:"#{field}_html"].to_s }
      end

      attribute(:fallback_options) do |form_description|
        form_description.fallback_options.options.map { Api::FallbackOptionResource.new(it).as_protobuf }
      end
    end
  end
end
