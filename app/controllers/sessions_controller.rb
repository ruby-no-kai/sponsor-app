class SessionsController < ApplicationController
  def new
  end

  def create
    contact = Contact.find_by(kind: :primary, email: params[:email])

    if contact
      token = SessionToken.create!(email: contact.email)
      SessionTokenMailer.with(token: token).notify.deliver_now
      redirect_to new_user_session_path, notice: t('.email_sent')
    else
      flash.now[:alert] = t('.no_email_found')
      render :new, status: 401
    end
  end

  def claim
    @session_token = SessionToken.active.find_by!(handle: params[:handle])
    @sponsorships = @session_token.sponsorships

    # TODO:
    @sponsorship = @sponsorships.last

    session[:sponsorship_id] = @sponsorship.id
    session[:session_token_id] = @session_token.id

    redirect_to session.delete(:back_to) || user_conference_sponsorship_path(@sponsorship.conference)
  end

  def destroy
    session.delete(:sponsorship_id)
    session.delete(:session_token_id)
    redirect_to '/'
  end
end
