# typed: strict
# frozen_string_literal: true

module Admin
  class BroadcastsController < Admin::ApplicationController
    before_action :set_conference
    before_action :set_broadcast, only: %i(show edit update dispatch_delivery)

    #: () -> void
    def index
      @broadcasts = conference.broadcasts.order(id: :desc) #: Broadcast::PrivateAssociationRelation?
    end

    #: () -> void
    def new
      @broadcast = Broadcast.new(conference:)
    end

    #: () -> void
    def create
      filter = recipient_filter
      @broadcast = Broadcast.new(broadcast_params)
      @broadcast.conference = conference
      @broadcast.staff = current_staff
      @broadcast.status = :created

      respond_to do |format|
        if @broadcast.save
          CreateBroadcastDeliveriesJob.perform_later(@broadcast, [filter].compact)
          format.html do
            redirect_to conference_broadcast_path(conference, @broadcast)
          end
        else
          format.html do
            render :new
          end
        end
      end
    end

    #: () -> void
    def show
    end

    #: () -> void
    def edit
    end

    #: () -> void
    def update
      respond_to do |format|
        if broadcast.update(broadcast_params)
          format.html { redirect_to conference_broadcast_path(conference, broadcast), notice: 'Broadcast was successfully updated.' }
        else
          format.html { render :edit }
        end
      end
    end

    #: () -> void
    def dispatch_delivery
      broadcast.update!(staff: current_staff)
      broadcast.perform_later!
      redirect_to conference_broadcast_path(conference, broadcast), notice: 'Dispatched'
    end

    #: () -> void
    private def set_broadcast
      @broadcast = conference.broadcasts.find_by!(id: params[:id]) #: Broadcast?
    end

    #: () -> void
    private def set_conference
      @conference = Conference.find_by!(slug: params[:conference_slug]) #: Conference?
      check_staff_conference_authorization!(conference)
    end

    #: () -> Conference
    private def conference = Must.because(@conference) { "set_conference runs before every action" }

    #: () -> Broadcast
    private def broadcast = Must.because(@broadcast) { "set_broadcast runs before show, edit, update and dispatch_delivery" }

    #: () -> ActionController::Parameters
    private def broadcast_params
      params.require(:broadcast).permit(
        :campaign,
        :description,
        :title,
        :body,
      )
    end

    #: () -> Rk::SponsorApp::Internal::BroadcastRecipientFilter?
    private def recipient_filter
      # TODO: apply plan and status, which the form offers, as BroadcastDeliveriesController does.
      BroadcastRecipientFilterParams.build(params.require(:recipient_filter).except(:plan_id, :status))
    end
  end
end
