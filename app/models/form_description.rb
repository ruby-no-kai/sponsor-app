class FormDescription < ApplicationRecord
  belongs_to :conference
  validates :conference, presence: true

  before_save :render_markdown

  def fallback_options=(value)
    @fallback_options_json_error = false
    case value
    when String
      if value.blank?
        write_attribute(:fallback_options, {})
      else
        begin
          write_attribute(:fallback_options, JSON.parse(value))
        rescue JSON::ParserError
          @fallback_options_json_error = true
          write_attribute(:fallback_options, value)
        end
      end
    when nil
      write_attribute(:fallback_options, {})
    else
      write_attribute(:fallback_options, value)
    end
  end

  validate :validate_fallback_options_json

  def validate_fallback_options_json
    if @fallback_options_json_error
      errors.add(:fallback_options, 'must be valid JSON')
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
