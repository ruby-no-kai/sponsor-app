# typed: strict
# frozen_string_literal: true

module Admin
  class BroadcastDeliveriesController < Admin::ApplicationController
    before_action :set_broadcast
    before_action :set_delivery, only: [:destroy]

    #: () -> void
    def create
      filter = recipient_filter
      if broadcast.ready?
        ApplicationRecord.transaction do
          broadcast.lock!
          if broadcast.ready?
            broadcast.update!(status: :modifying)
            CreateBroadcastDeliveriesJob.perform_later(broadcast, [filter].compact)
          else
            flash[:error] = 'Unable to modify'
          end
        end
      else
        flash[:error] = 'Unable to modify'
      end
      redirect_to conference_broadcast_path(conference, broadcast)
    end

    #: () -> void
    def destroy
      unless delivery.ready?
        return render status: :forbidden, plain: 'Forbidden'
      end

      delivery.destroy
      redirect_to conference_broadcast_path(conference, broadcast)
    end

    #: () -> void
    private def set_broadcast
      @conference = Conference.find_by!(slug: params[:conference_slug]) #: Conference?
      check_staff_conference_authorization!(conference)
      @broadcast = conference.broadcasts.find_by!(id: params[:broadcast_id]) #: Broadcast?
    end

    #: () -> void
    private def set_delivery
      @delivery = broadcast.deliveries.find_by!(id: params[:id]) #: BroadcastDelivery?
    end

    #: () -> Conference
    private def conference = Must.because(@conference) { "set_broadcast runs before every action" }

    #: () -> Broadcast
    private def broadcast = Must.because(@broadcast) { "set_broadcast runs before every action" }

    #: () -> BroadcastDelivery
    private def delivery = Must.because(@delivery) { "set_delivery runs before destroy" }

    #: () -> Rk::SponsorApp::Internal::BroadcastRecipientFilter?
    private def recipient_filter
      BroadcastRecipientFilterParams.build(params.require(:recipient_filter))
    end
  end
end
