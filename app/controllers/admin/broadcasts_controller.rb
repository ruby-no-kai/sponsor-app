class Admin::BroadcastsController < Admin::ApplicationController
  before_action :set_conference
  before_action :set_broadcast, only: %i(show edit update destroy dispatch_delivery)

  def index
    @broadcasts = @conference.broadcasts.order(id: :desc)
  end

  def new
    @broadcast = Broadcast.new(conference: @conference)
  end

  def create
    @broadcast = Broadcast.new(broadcast_params)
    @broadcast.conference = @conference
    @broadcast.staff = current_staff
    @broadcast.status = :created

    respond_to do |format|
      if @broadcast.save
        CreateBroadcastDeliveriesJob.perform_later(@broadcast, [recipient_filter].compact)
        format.html do
          redirect_to conference_broadcast_path(@conference, @broadcast)
        end
      else
        format.html do
          render :new
        end
      end
    end
  end

  def show
  end

  def edit
  end

  def update
    respond_to do |format|
      if @broadcast.update(broadcast_params)
        format.html { redirect_to conference_broadcast_path(@conference, @broadcast), notice: 'Broadcast was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  def dispatch_delivery
    @broadcast.update!(staff: current_staff)
    @broadcast.perform_later!
    redirect_to conference_broadcast_path(@conference, @broadcast), notice: 'Dispatched'
  end

  private

  def set_broadcast
    @broadcast = @conference.broadcasts.find_by!(id: params[:id])
  end

  def set_conference
    @conference = Conference.find_by!(slug: params[:conference_slug])
  end

  def broadcast_params
    params.require(:broadcast).permit(
      :campaign,
      :description,
      :title,
      :body,
    )
  end

  def recipient_filter
    params.require(:recipient_filter).permit(
      :kind,
      :locale,
      :exhibitors,
      :id,
      :exclude_current_sponsors,
      :emails,
      sponsorship_ids: [],
    )
  end
end
