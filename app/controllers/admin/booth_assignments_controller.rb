class Admin::BoothAssignmentsController < ::Admin::ApplicationController
  before_action :set_conference

  def show
    @not_withdrawn_sponsorships = @conference.sponsorships
      .includes(:plan)
      .not_withdrawn
      .where(booth_requested: true)
      .order('plans.booth_size desc, sponsorships.name asc')
    @sponsorships = @conference.sponsorships
      .includes(:plan)
      .active
      .where('(sponsorships.booth_requested = TRUE OR sponsorships.booth_assigned = TRUE)')
      .order('plans.booth_size desc, sponsorships.name asc')
    @exhibitors = @sponsorships.select(&:booth_assigned?)
  end

  def update
    @sponsorships = @conference.sponsorships
    @sponsorships.each do |sponsorship|
      sponsorship.booth_assigned = booth_assignments_param[sponsorship.id.to_s] == '1'
      if sponsorship.booth_assigned_changed?
        sponsorship.staff = current_staff
        sponsorship.save!(validate: false)
        ProcessSponsorshipEditJob.perform_later(sponsorship.last_editing_history)
      end
    end
    redirect_to conference_booth_assignment_path(@conference), notice: 'Assignment updated'
  end

  private

  def set_conference
    @conference = Conference.find_by!(slug: params[:conference_slug])
    check_staff_conference_authorization!(@conference)
  end

  def booth_assignments_param
    params.require(:booth_assignments).permit!
  end
end
