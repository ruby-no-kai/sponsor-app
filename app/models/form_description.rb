# typed: strict
# frozen_string_literal: true

class FormDescription < ApplicationRecord
  FallbackOptionCondition = Data.define(:plans, :booth_request) do
    #: () -> Hash[Symbol, untyped]
    def as_json = to_h.compact

    #: () -> bool
    def valid?
      plans_valid = plans.nil? || plans.is_a?(Array)
      booth_valid = booth_request.nil? || [true, false].include?(booth_request)
      plans_valid && booth_valid
    end
  end

  FallbackOption = Data.define(:value, :name, :conditions, :priority_human) do
    #: () -> bool
    def valid?
      return false if value.blank? || name.blank?
      return false if priority_human.present? && !priority_human.is_a?(Array)

      conds = conditions
      return true if conds.nil?

      conds.is_a?(Array) && conds.all? { |cond| cond.is_a?(FallbackOptionCondition) && cond.valid? }
    end

    #: () -> Hash[Symbol, untyped]
    def as_json = to_h.merge(conditions: conditions&.map(&:as_json)).compact

    #: () -> Hash[Symbol, String]
    def to_dataset
      dataset = {} #: Hash[Symbol, String]
      conds = conditions.presence
      dataset[:conditions] = JSON.generate(conds.map(&:as_json)) if conds
      dataset[:priority_human] = JSON.generate(priority_human) if priority_human.present?
      dataset
    end
  end

  belongs_to :conference

  validate :validate_fallback_options_json

  #: () -> String
  def to_param
    locale
  end

  before_save :render_markdown

  #: () -> Array[FallbackOption]
  def fallback_options
    build_fallback_options(read_attribute(:fallback_options))
  end

  #: (String | Array[untyped] | nil value) -> void
  def fallback_options=(value)
    @fallback_options_error = false #: bool?

    # Parse input into array
    parsed_value = case value
    when String
      if value.blank?
        []
      else
        begin
          JSON.parse(value)
        rescue JSON::ParserError
          @fallback_options_error = true
          return
        end
      end
    when nil
      []
    else
      value
    end

    unless parsed_value.is_a?(Array) && parsed_value.all?(Hash)
      @fallback_options_error = true
      return
    end

    options = build_fallback_options(parsed_value)
    unless options.all?(&:valid?)
      @fallback_options_error = true
      return
    end

    write_attribute(:fallback_options, parsed_value)
  end

  #: (untyped raw_array) -> Array[FallbackOption]
  private def build_fallback_options(raw_array)
    if raw_array.is_a?(Hash)
      return raw_array.map { |value, name| FallbackOption.new(value:, name:, conditions: nil, priority_human: nil) }
    end

    return [] if raw_array.blank?

    raw_array.map do |opt|
      # Malformed conditions are kept as-is so FallbackOption#valid? rejects them.
      conditions = opt['conditions'].presence
      if conditions.is_a?(Array)
        conditions = conditions.map do |cond|
          next cond unless cond.is_a?(Hash)

          FallbackOptionCondition.new(
            plans: cond['plans'],
            booth_request: cond['booth_request'],
          )
        end
      end

      FallbackOption.new(
        value: opt['value'],
        name: opt['name'],
        conditions:,
        priority_human: opt['priority_human'],
      )
    end
  end

  #: () -> void
  private def validate_fallback_options_json
    if @fallback_options_error
      errors.add(:fallback_options, 'must be valid JSON struct')
    end
  end

  #: () -> void
  def render_markdown
    %i(
      head
      plan_help
      booth_help
      policy_help
      ticket_help
      sponsor_event_help
      event_policy
    ).each do |field|
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
end
