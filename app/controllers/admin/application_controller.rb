class Admin::ApplicationController < ::ApplicationController
  layout 'admin'
  before_action :require_staff

  class RestrictedAccessForbidden < StandardError; end

  rescue_from(RestrictedAccessForbidden) do
    render status: 403, plain: 'Forbidden'
  end

  private def check_staff_conference_authorization!(conference)
    if current_staff.restricted_repos
      raise RestrictedAccessForbidden unless current_staff.restricted_repos.include?(conference.github_repo&.name)
    end
  end

  private def require_unrestricted_staff
    if current_staff.restricted_repos
      raise RestrictedAccessForbidden
    end
  end
end
