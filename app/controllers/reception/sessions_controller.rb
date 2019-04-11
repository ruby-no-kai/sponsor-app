class Reception::SessionsController < ::ApplicationController
  def assume
    id, key = params[:handle]&.split('--', 2)
    raise ActiveRecord::RecordNotFound unless id && key
    @conference = Conference.find_by!(id: id, reception_key: key)
    session[:reception_access] ||= {}
    session[:reception_access][@conference.id.to_s] = true
    redirect_to reception_conference_path(@conference)
  end
end
