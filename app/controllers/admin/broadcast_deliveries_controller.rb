class Admin::BroadcastDeliveriesController < Admin::ApplicationController
  before_action :set_broadcast
  before_action :set_delivery, only: [:destroy]

  def create
    if @broadcast.ready?
      ApplicationRecord.transaction do
        @broadcast.lock!
        if @broadcast.ready?
          @broadcast.update!(status: :modifying)
          CreateBroadcastDeliveriesJob.perform_later(@broadcast, [recipient_filter])
        else
          flash[:error] = 'Unable to modify'
        end
      end
    else
      flash[:error] = 'Unable to modify'
    end
    redirect_to conference_broadcast_path(@conference, @broadcast)
  end

  def destroy
    unless @delivery.ready?
      return render status: 403, plain: 'Forbidden'
    end

    @delivery.destroy
    redirect_to conference_broadcast_path(@conference, @broadcast)
  end

  private

  def set_broadcast
    @conference = Conference.find_by!(slug: params[:conference_slug])
    @broadcast = @conference.broadcasts.find_by!(id: params[:broadcast_id])
  end

  def set_delivery
    @delivery = @broadcast.deliveries.find_by!(id: params[:id])
  end

  def recipient_filter
    params.require(:recipient_filter).permit(
      :kind,
      :locale,
      :exhibitors,
      :id,
      :exclude_current_sponsors,
      :emails,
      :plan_id,
      :status,
      sponsorship_ids: [],
    )
  end
end
