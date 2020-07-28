class Admin::ConferencesController < Admin::ApplicationController
  before_action :set_conference, only: [:show, :edit, :update, :destroy, :attendees_keeper, :sponsors_yml, :sponsors_json, :asset_urls, :table_view]

  def index
    @conferences = Conference.all
  end

  def show
    @plans_with_count = @conference
      .plans
      .left_joins(:sponsorships)
      .group(:id)
      .select('plans.*, COUNT(sponsorships.plan_id) as cnt')
      .map {|_| [_, _.cnt, _.capacity] }
      .sort_by { |plan, _cnt, _capa| -plan.rank }
  end

  def attendees_keeper
  end

  def sponsors_yml
    render plain: GenerateSponsorsYamlFileJob.new(@conference, push: false).tap(&:perform_now).yaml_data
  end

  def sponsors_json
    render plain: GenerateSponsorsYamlFileJob.new(@conference, push: false).tap(&:perform_now).json_data
  end

  def table_view
    @sponsorships = @conference.sponsorships
      .includes_contacts
      .includes_requests
  end

  def asset_urls
    render json: {
      files: @conference.sponsorships.includes(:asset_file).map(&:asset_file).compact.map do |asset|
        [asset.filename, asset.download_url]
      end,
    }.to_json
  end

  def new
    @conference = Conference.new
  end

  def edit
  end

  def create
    @conference = Conference.new(conference_params)

    respond_to do |format|
      if @conference.save
        format.html { redirect_to @conference, notice: 'Conference was successfully created.' }
      else
        format.html { render :new }
      end
    end
  end

  def update
    respond_to do |format|
      if @conference.update(conference_params)
        format.html { redirect_to @conference, notice: 'Conference was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  def destroy
    @conference.destroy
    respond_to do |format|
      format.html { redirect_to _conferences_url, notice: 'Conference was successfully destroyed.' }
    end
  end

  private

  def set_conference
    @conference = Conference.find_by!(slug: params[:slug])
  end

  def conference_params
    params.require(:conference).permit(
      :name,
      :slug,
      :application_opens_at,
      :application_closes_at,
      :ticket_distribution_starts_at,
      :amendment_closes_at,
      :booth_capacity,
      :contact_email_address,
      :additional_attendees_registration_open,
      :github_repo,
      :hidden,
      :no_plan_allowed,
    )
  end
end
