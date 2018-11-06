class Admin::SponsorshipsController < Admin::ApplicationController
  before_action :set_sponsorship

  def show
  end

  def edit
    @sponsorship.build_alternate_billing_contact unless @sponsorship.alternate_billing_contact
    @sponsorship.build_billing_request unless @sponsorship.billing_request
    @sponsorship.build_customization_request unless @sponsorship.customization_request
    @sponsorship.build_note unless @sponsorship.note
  end

  def update
    respond_to do |format|
      if @sponsorship.update(sponsorship_params)
        format.html { redirect_to conference_sponsorship_path(@conference, @sponsorship), notice: 'Sponsorship was successfully updated.' }
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

      :customization,
      :customization_name,
      :booth_assigned,

      contact_attributes: %i(id email address organization unit name),
      alternate_billing_contact_attributes: %i(_keep id email address organization unit name),

      billing_request: %i(id body),
      customization_request: %i(id body),
      other_request: %i(id body),
    ).tap do |sp|
      unless sp[:alternate_billing_contact_attributes].nil? || sp[:alternate_billing_contact_attributes][:_keep] == '1'
        (sp[:alternate_billing_contact_attributes] ||= {})[:_destroy] = '1'
      end
    end
  end

  def set_sponsorship
    @sponsorship = Sponsorship.find(params[:id])
    @conference = @sponsorship.conference
  end
end
