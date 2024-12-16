module MarkdownBody
  def html
    if self.persisted?
      Rails.cache.fetch("#{self.class.name}:html:#{id}/#{updated_at.to_f}", expires_in: 1.month) { render_html }.html_safe
    else
      render_html.html_safe
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
