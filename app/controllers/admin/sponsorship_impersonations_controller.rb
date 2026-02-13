class Admin::SponsorshipImpersonationsController < Admin::ApplicationController
  before_action :require_sponsor_impersonation

  def create
    @conference = Conference.find_by!(slug: params[:conference_slug])
    check_staff_conference_authorization!(@conference)
    @sponsorship = Sponsorship.where(conference: @conference).find(params[:sponsorship_id])

    token = SessionToken.create!(
      email: @sponsorship.contact.email,
      expires_at: 1.minute.from_now,
    )

    redirect_to claim_user_session_path(token)
  end

  private

  def require_sponsor_impersonation
    unless Rails.configuration.x.dev.sponsor_impersonation
      raise ActionController::RoutingError, 'Not Found'
    end
  end
end
