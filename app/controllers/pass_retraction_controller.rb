class PassRetractionController < ApplicationController
  before_action :require_sponsorship_session
  before_action :set_conference_and_sponsorship

  def new
    @retraction = find_or_prepare_retraction
    redirect_to user_conference_sponsorship_retraction_path(@conference, params[:id]) if @retraction.completed?
  rescue Faraday::ResourceNotFound
    raise ActiveRecord::RecordNotFound
  end

  def create
    @retraction = find_or_prepare_retraction
    @retraction.reason = retraction_params[:reason]

    if @retraction.save
      RetractTitoTicketJob.perform_now(@retraction)
      redirect_to user_conference_sponsorship_retraction_path(@conference, params[:id])
    else
      render :new, status: :unprocessable_entity
    end
  rescue Faraday::ResourceNotFound
    raise ActiveRecord::RecordNotFound
  end

  def show
    @retraction = TitoTicketRetraction.find_by!(
      sponsorship: @sponsorship,
      tito_registration_id: params[:id]
    )
  end

  private

  def set_conference_and_sponsorship
    @sponsorship = current_sponsorship
    @conference = @sponsorship.conference
    raise ActiveRecord::RecordNotFound unless @conference.tito_slug.present?
  end

  def find_or_prepare_retraction
    TitoTicketRetraction.find_by(
      sponsorship: @sponsorship,
      tito_registration_id: params[:id]
    ) || TitoTicketRetraction.prepare(@sponsorship, params[:id])
  end

  def retraction_params
    params.require(:tito_ticket_retraction).permit(:reason)
  end
end
