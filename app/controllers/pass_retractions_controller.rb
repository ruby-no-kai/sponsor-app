# typed: strict
# frozen_string_literal: true

class PassRetractionsController < ApplicationController
  before_action :require_sponsorship_session
  before_action :set_conference_and_sponsorship
  before_action :require_pass_retraction_enabled, only: [:create]

  #: () -> void
  def new
    @retraction = find_or_prepare_retraction
    @pass_retraction_disabled = !conference.pass_retraction_enabled? #: bool?
    redirect_to user_conference_sponsorship_retraction_path(conference, params[:id]) if @retraction.completed?
  rescue HTTPX::HTTPError => e
    raise unless e.status == 404

    raise ActiveRecord::RecordNotFound
  end

  #: () -> void
  def create
    @retraction = find_or_prepare_retraction
    @retraction.reason = retraction_params[:reason]

    if @retraction.save
      RetractTitoTicketJob.perform_now(@retraction)
      redirect_to user_conference_sponsorship_retraction_path(conference, params[:id])
    else
      render :new, status: :unprocessable_entity
    end
  rescue HTTPX::HTTPError => e
    raise unless e.status == 404

    raise ActiveRecord::RecordNotFound
  end

  #: () -> void
  def show
    @retraction = TitoTicketRetraction.find_by!(
      sponsorship:,
      tito_registration_id: params[:id],
    ) #: TitoTicketRetraction?
  end

  #: () -> void
  private def set_conference_and_sponsorship
    @sponsorship = current_sponsorship #: Sponsorship?
    @conference = Must.expect(sponsorship.conference) #: Conference?
    raise ActiveRecord::RecordNotFound if conference.tito_slug.blank?
  end

  #: () -> TitoTicketRetraction
  private def find_or_prepare_retraction
    TitoTicketRetraction.find_by(
      sponsorship:,
      tito_registration_id: params[:id],
    ) || TitoTicketRetraction.prepare(sponsorship, params[:id])
  end

  #: () -> ActionController::Parameters
  private def retraction_params
    params.require(:tito_ticket_retraction).permit(:reason)
  end

  #: () -> void
  private def require_pass_retraction_enabled
    raise ActiveRecord::RecordNotFound unless conference.pass_retraction_enabled?
  end

  #: () -> Sponsorship
  private def sponsorship = Must.because(@sponsorship) { "set_conference_and_sponsorship runs before every action" }

  #: () -> Conference
  private def conference = Must.because(@conference) { "set_conference_and_sponsorship runs before every action" }
end
