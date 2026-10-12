# typed: strict
# frozen_string_literal: true

module Admin
  class ApplicationController < ::ApplicationController
    layout 'admin'
    before_action :require_staff

    class RestrictedAccessForbidden < StandardError; end

    rescue_from(RestrictedAccessForbidden) do
      render status: :forbidden, plain: 'Forbidden'
    end

    #: (Conference) -> void
    private def check_staff_conference_authorization!(conference)
      if current_staff.restricted_repos
        raise RestrictedAccessForbidden unless conference.allow_restricted_access
        raise RestrictedAccessForbidden unless current_staff.restricted_repos.include?(conference.github_repo&.name)
      end
    end

    #: () -> void
    private def require_unrestricted_staff
      if current_staff.restricted_repos
        raise RestrictedAccessForbidden
      end
    end
  end
end
