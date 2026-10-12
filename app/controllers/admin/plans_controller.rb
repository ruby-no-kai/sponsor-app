# typed: strict
# frozen_string_literal: true

module Admin
  class PlansController < Admin::ApplicationController
    before_action :set_conference
    before_action :set_plan, only: [:edit, :update]

    #: () -> void
    def index
      @plans = conference.plans.order(:rank) #: Plan::PrivateAssociationRelation?
    end

    #: () -> void
    def new
      @plan = Plan.new(conference:)
    end

    #: () -> void
    def edit
    end

    #: () -> void
    def create
      @plan = Plan.new(plan_params)
      @plan.conference = conference

      respond_to do |format|
        if @plan.save
          format.html { redirect_to conference_plans_path(conference), notice: 'Plan was successfully created.' }
        else
          format.html { render :new }
        end
      end
    end

    #: () -> void
    def update
      respond_to do |format|
        if plan.update(plan_params)
          format.html { redirect_to conference_plans_path(conference), notice: 'Plan was successfully updated.' }
        else
          format.html { render :edit }
        end
      end
    end

    #: () -> ActionController::Parameters
    private def plan_params
      params.require(:plan).permit(
        :name,
        :rank,
        :price_text,
        :price,
        :price_booth,
        :summary,
        :capacity,
        :number_of_guests,
        :booth_size,
        :words_limit,
        :auto_acceptance,
        :talkable,
        :closes_at,
      )
    end

    #: () -> void
    private def set_conference
      @conference = Conference.find_by!(slug: params[:conference_slug]) #: Conference?
      check_staff_conference_authorization!(conference)
    end

    #: () -> void
    private def set_plan
      @plan = Plan.where(conference:).find(params[:id]) #: Plan?
    end

    #: () -> Conference
    private def conference = Must.because(@conference) { "set_conference runs before every action" }

    #: () -> Plan
    private def plan = Must.because(@plan) { "set_plan runs before edit and update" }
  end
end
