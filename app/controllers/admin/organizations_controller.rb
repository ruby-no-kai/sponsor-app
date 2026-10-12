# typed: strict
# frozen_string_literal: true

module Admin
  class OrganizationsController < Admin::ApplicationController
    before_action :require_unrestricted_staff
    before_action :set_organization, except: %i[index new create]

    #: () -> void
    def index
      @organizations = Organization.all.order(:name) #: Organization::PrivateRelation?
    end

    #: () -> void
    def show
      @sponsorships = organization.sponsorships.includes(:conference, :plan).order(id: :desc) #: Sponsorship::PrivateAssociationRelation?
      @conferences_open_for_application = Conference.application_open.order(id: :desc) #: Conference::PrivateRelation?
    end

    #: () -> void
    def new
      @organization = Organization.new
    end

    #: () -> void
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

    #: () -> void
    def edit
    end

    #: () -> void
    def update
      respond_to do |format|
        if organization.update(organization_params)
          format.html { redirect_to organization_path(organization), notice: 'Organization was successfully updated.' }
        else
          format.html { render :edit }
        end
      end
    end

    #: () -> void
    private def set_organization
      @organization = Organization.find_by!(domain: params[:slug]) #: Organization?
    end

    #: () -> Organization
    private def organization = Must.because(@organization) { "set_organization runs before every member action" }

    #: () -> ActionController::Parameters
    private def organization_params
      params.require(:organization).permit(:name, :domain, :auto_acceptance_disabled)
    end
  end
end
