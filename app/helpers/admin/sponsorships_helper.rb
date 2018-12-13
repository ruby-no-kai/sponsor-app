module Admin::SponsorshipsHelper
  def front_mail_to_link(to, from: nil)
    base = "mailto:#{URI.encode_www_form_component(to).gsub('%40', ?@)}"
    extras = []
    extras << "from=#{URI.encode_www_form_component(from).gsub('%40', ?@)}" if from
    unless extras.empty?
      base << "?#{extras.join(?&)}"
    end
    "https://app.frontapp.com/compose?mailto=#{URI.encode_www_form_component(base)}"
  end
end
