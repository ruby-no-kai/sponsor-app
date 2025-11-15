class FormDescription < ApplicationRecord
  FallbackOption = Data.define(:value, :name, :booth_request, :plans) do
    def valid?
      value.present? && name.present?
    end

    def as_json = to_h.compact

    def to_dataset
      dataset = to_h.except(:value, :name).compact
      dataset[:plans] = dataset[:plans].join(',') if dataset[:plans].is_a?(Array)
      dataset
    end
  end

  belongs_to :conference

  validate :validate_fallback_options_json

  before_save :render_markdown

  def fallback_options
    build_fallback_options(read_attribute(:fallback_options))
  end

  def fallback_options=(value)
    @fallback_options_error = false

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
          return value
        end
      end
    when nil
      []
    else
      value
    end

    unless parsed_value.is_a?(Array)
      @fallback_options_error = true
      return value
    end

    options = build_fallback_options(parsed_value)
    unless options.all?(&:valid?)
      @fallback_options_error = true
      return value
    end

    write_attribute(:fallback_options, parsed_value)
  end

  private def build_fallback_options(raw_array)
    if raw_array.is_a?(Hash)
      return raw_array.map { |value, name|  FallbackOption.new(value:, name:, booth_request: nil, plans: nil) }
    end

    return [] if raw_array.blank?

    raw_array.map do |opt|
      FallbackOption.new(
        value: opt['value'],
        name: opt['name'],
        booth_request: opt['booth_request'],
        plans: opt['plans']
      )
    end
  end

  private def validate_fallback_options_json
    if @fallback_options_error
      errors.add(:fallback_options, 'must be valid JSON struct')
    end
  end

  def render_markdown
    %i(
      head
      plan_help
      booth_help
      policy_help
      ticket_help
    ).each do |field|
      self[:"#{field}_html"] = Commonmarker.to_html(
        self[field],
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
            header_ids: "#{self.id}--",
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
