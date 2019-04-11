class Reception::RegistrationsController < ::Reception::ApplicationController
  skip_before_action :set_conference, only: %i(short_show)

  # Ticket code links to this page
  def short_show
    id,code = params[:handle]&.split('-', 2)
    @conference = Conference.find(id)
    redirect_to reception_conference_registration_path(@conference, code)
  end

  def show
    @ticket = @conference.tickets.find_by!(code: params[:code])
  end

  def update
    code = params[:code]&.split('-')&.last&.upcase
    @ticket = @conference.tickets.find_by!(code: code)

    if @ticket.check_in(authorized: true)
      render json: {ok: true, ticket: @ticket.as_json}
    else
      render json: {ok: false, errors: @ticket.errors.full_messages.to_a, ticket: @ticket.as_json}
    end
  end

  # Manual registration
  def new
    @ticket = Ticket.new
  end

  def create
    @ticket = Ticket.new(ticket_params)
    @ticket.kind ||= :attendee
    if @ticket.check_in(authorized: false)
      UnauthorizedTicketWarningMailer.with(ticket: @ticket).notify.deliver_later
      redirect_to reception_conference_path(@ticket.conference), notice: "Manual check-in successfully completed."
    else
      render :new
    end
  end

  private def ticket_params
    params.require(:ticket).permit(
      :sponsorship_id,
      :name,
      :email,
      :kind,
    )
  end
end
