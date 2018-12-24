module MarkdownBody
  def html
    if self.persisted?
      Rails.cache.fetch("#{self.class.name}:html:#{id}/#{updated_at.to_f}", expires_in: 1.month) { render_html }.html_safe
    else
      render_html.html_safe
    end
  end

  def render_html
    CommonMarker.render_html(body, %i(GITHUB_PRE_LANG), %i(tagfilter autolink table strikethrough))
  end
end
