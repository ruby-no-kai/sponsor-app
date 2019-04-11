class Reception::ApplicationController < ::ApplicationController
  layout 'reception'
  before_action :set_conference
  before_action :require_reception_access

  private def set_conference
    slug = params[:conference_slug] || params[:slug]
    if slug
      @conference = Conference.find_by!(slug: slug)
    end
  end

  private def require_reception_access
    case
    when current_staff
      return true
    when @conference && session[:reception_access]&.fetch(@conference.id.to_s, nil)
      return true
    end
    render status: 403, plain: 'forbidden'
  end

end
