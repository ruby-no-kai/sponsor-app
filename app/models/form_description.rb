# typed: strict
# frozen_string_literal: true

class FormDescription < ApplicationRecord
  # Markdown columns, each rendered into its `_html` column on save.
  MARKDOWN_FIELDS = %i[
    head
    plan_help
    booth_help
    policy_help
    ticket_help
    sponsor_event_help
    event_policy
  ].freeze #: Array[Symbol]

  belongs_to :conference

  attribute :fallback_options,
    Protobufable::JsonType.new(Rk::SponsorApp::Internal::FallbackOptions, preserve_proto_fieldnames: true),
    default: -> { Rk::SponsorApp::Internal::FallbackOptions.new }

  validate :validate_fallback_option_plans

  #: () -> String
  def to_param
    locale
  end

  before_save :render_markdown

  #: () -> void
  def render_markdown
    MARKDOWN_FIELDS.each do |field|
      self[:"#{field}_html"] = Commonmarker.to_html(
        self[field] || '',
        options: {
          render: {
            unsafe: true,
          },
          extension: {
            strikethrough: true,
            tagfilter: false,
            table: true,
            autolink: true,
            tasklist: true,
            superscript: true,
            header_ids: "#{id}--",
            footnotes: true,
            description_lists: true,
            front_matter_delimiter: '---',
            shortcodes: true,
          },
        },
        plugins: {
          syntax_highlighter: nil,
        },
      )
    end
  end

  # The .proto's rules cover the shape. Plan names need the database, and a condition naming no
  # plan of the conference would never match.
  #: () -> void
  private def validate_fallback_option_plans
    known = nil #: Array[String]?
    fallback_options.options.each_with_index do |option, option_index|
      option.conditions.each_with_index do |condition, condition_index|
        next if condition.plans.empty?

        known ||= conference&.plans&.pluck(:name) || []
        unknown = condition.plans.to_a - known
        next if unknown.empty?

        verb = unknown.one? ? 'is not a plan' : 'are not plans'
        errors.add(
          :fallback_options,
          :unknown_plan,
          message: "option #{option_index + 1}, condition #{condition_index + 1} names " \
            "#{unknown.to_sentence}, which #{verb} of the conference",
        )
      end
    end
  end
end
