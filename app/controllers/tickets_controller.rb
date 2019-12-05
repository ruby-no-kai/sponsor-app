class TicketsController < ApplicationController
  before_action :set_conference
  before_action :require_ticket, only: %i(code show)

  def new
    @sponsorship = @conference.sponsorships.find_by!(ticket_key: params[:key])
    if !params[:force] && current_ticket&.sponsorship_id == @sponsorship.id
      redirect_to user_conference_ticket_path(@conference)
    end

    @ticket = Ticket.new(sponsorship: @sponsorship)
  end

  def new_code
    render plain: RQRCode::QRCode.new(new_user_conference_ticket_url(@conference, key: params[:key]), :l).as_svg(module_size: 6), content_type: 'image/svg+xml'
  end

  def create
    @sponsorship = @conference.sponsorships.find_by!(ticket_key: params[:ticket_key])
    @ticket = Ticket.new(ticket_params)
    @ticket.kind ||= :attendee
    @ticket.conference = @conference
    @ticket.sponsorship = @sponsorship

    if @ticket.save
      TicketRetrievalMailer.with(ticket: @ticket).notify.deliver_later if @ticket.email.present?
      (session[:ticket_ids] ||= {})[@conference.id.to_s] = @ticket.id
      redirect_to user_conference_ticket_path(@conference)
    else
      render :new
    end
  end

  def show
    @sponsorship = @ticket.sponsorship
  end

  def code
    @ticket = current_ticket
    render plain: RQRCode::QRCode.new(reception_ticket_url(handle: @ticket.to_param), :h).as_svg(module_size: 6), content_type: 'image/svg+xml'
  end

  def retrieve
    @ticket = @conference.tickets.find_by!(handle: params[:handle])
    (session[:ticket_ids] ||= {})[@ticket.conference_id.to_s] = @ticket.id
    redirect_to user_conference_ticket_path(@conference)
  end

  private def set_conference
    @conference = Conference.find_by!(slug: params[:conference_slug])
    raise ActiveRecord::RecordNotFound unless @conference.distributing_ticket?
  end

  helper_method private def current_ticket
    return @ticket if defined? @ticket
    session[:ticket_ids] ||= {}
    id = session[:ticket_ids][@conference.id.to_s]
    @ticket = id && Ticket.find_by(id: id)
  end

  private def require_ticket
    raise ActiveRecord::RecordNotFound unless current_ticket
  end

  private def set_locale
    if params[:hl] 
      if I18n.available_locales.include?(params[:hl].to_sym)
        session[:hl] = params[:hl].to_sym
      else
        session.delete(:hl)
      end
    end

    if session[:hl]
      I18n.locale = session[:hl]
    end
  end

  private def ticket_params
    params.require(:ticket).permit(
      :name,
      :email,
      :kind
    )
  end
end
