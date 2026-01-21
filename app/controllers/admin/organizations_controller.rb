class Admin::OrganizationsController < Admin::ApplicationController
  before_action :set_organization, except: %i[index new create]

  def index
    @organizations = Organization.all.order(:name)
  end

  def show
    @sponsorships = @organization.sponsorships.includes(:conference, :plan).order(id: :desc)
    @conferences_open_for_application = Conference.application_open.order(id: :desc)
  end

  def new
    @organization = Organization.new
  end

  def create
    @organization = Organization.new(organization_params)
    respond_to do |format|
      if @organization.save
        format.html { redirect_to organization_path(@organization), notice: 'Organization was successfully created.' }
      else
        format.html { render :new }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @organization.update(organization_params)
        format.html { redirect_to organization_path(@organization), notice: 'Organization was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  private

  def set_organization
    @organization = Organization.find_by!(domain: params[:slug])
  end

  def organization_params
    params.require(:organization).permit(:name, :domain, :auto_acceptance_disabled)
  end
end
