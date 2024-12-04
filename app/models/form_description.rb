class FormDescription < ApplicationRecord
  belongs_to :conference
  validates :conference, presence: true

  before_save :render_markdown

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
