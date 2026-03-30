# frozen_string_literal: true

module MarkdownBody
  def html
    if persisted?
      Rails.cache.fetch("#{self.class.name}:html:#{id}/#{updated_at.to_f}", expires_in: 1.month) { render_html }.html_safe # rubocop:disable Rails/OutputSafety
    else
      render_html.html_safe # rubocop:disable Rails/OutputSafety
    end
  end

  def render_html
    Commonmarker.to_html(
      body,
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
