class SponsorshipsController < ApplicationController
  def show
    unless current_sponsorship
      return redirect_to new_user_conference_sponsorship_path(conference: @conference)
    end
    @sponsorship = current_sponsorship
    @conference = current_sponsorship&.conference
    raise ActiveRecord::RecordNotFound unless @conference
  end

  def edit
    @sponsorship = current_sponsorship
    @conference = current_sponsorship&.conference
    raise ActiveRecord::RecordNotFound unless @conference&.amendment_open?
  end

  def new
    return render(status: 404, plain: '404') if current_sponsorship
    return render(:closed, status: 403) unless @conference&.application_open?

    @conference = Conference.application_open.find(params[:conference_id])
    @sponsorship = Sponsorship.new(conference: @conference)
    @sponsorship.build_contact
    @sponsorship.build_alternate_billing_contact
    @sponsorship.build_billing_request
    @sponsorship.build_customization_request
    @sponsorship.build_note
  end

  def create
    return render(status: 404, plain: '404') if current_sponsorship
    @conference = Conference.application_open.find(params[:conference_id])
    @sponsorship = Sponsorship.new(sponsorship_params)
    @sponsorship.locale = I18n.locale
    @sponsorship.conference = @conference
    @sponsorship.assume_organization

    respond_to do |format|
      if @sponsorship.save
        session[:sponsorship_id] = @sponsorship.id
        format.html { redirect_to user_conference_sponsorship_path(conference: @conference), notice: t('.notice') }
      else
        format.html { render :new }
      end
    end
  end

  def update
    @sponsorship = current_sponsorship
    @conference = current_sponsorship&.conference
    raise ActiveRecord::RecordNotFound unless conference&.amendment_open?

    @sponsorship.locale = I18n.locale
    respond_to do |format|
      if @sponsorship.update(sponsorship_params)
        format.html { redirect_to user_conference_sponsorship_path(conference: @conference), notice: 'Your application was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  private

  def sponsorship_params
    params.require(:sponsorship).permit(
      :plan_id,
      :name,
      :url,
      :profile,
      :logo_key,
      :booth_requested,
      contact_attributes: %i(id email address organization unit name),
      alternate_billing_contact_attributes: %i(_keep id email address organization unit name),
      billing_request: %i(id body),
      customization_request: %i(id body),
      other_request: %i(id body),
    ).tap do |sp|
      unless sp[:alternate_billing_contact_attributes].nil? || sp[:alternate_billing_contact_attributes].delete(:_keep) == '1'
        (sp[:alternate_billing_contact_attributes] ||= {})[:_destroy] = '1'
      end
    end
  end
end
