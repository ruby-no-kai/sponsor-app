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
      self[:"#{field}_html"] = CommonMarker.render_html(self[field], %i(GITHUB_PRE_LANG), %i(tagfilter autolink table strikethrough))
    end
  end
end
