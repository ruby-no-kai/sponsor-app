class SponsorshipStaffNote < ApplicationRecord
  belongs_to :sponsorship
  belongs_to :staff

  def pin?
    stickiness > 0
  end

  def html
    if self.persisted?
      Rails.cache.fetch("sponsorship_staff_notes:html/#{id}/#{updated_at.to_f}") { render_html }.html_safe
    else
      render_html.html_safe
    end
  end

  def render_html
    CommonMarker.render_html(body, %i(GITHUB_PRE_LANG), %i(tagfilter autolink table strikethrough))
  end
end
