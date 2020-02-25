class Admin::SponsorshipsController < Admin::ApplicationController
  before_action :set_sponsorship

  def show
    @pinned_staff_notes = @sponsorship.staff_notes.where('stickiness > 0').order(stickiness: :desc, created_at: :desc).includes(:staff)
    @staff_notes = @sponsorship.staff_notes.where('stickiness = 0').order(stickiness: :desc, created_at: :desc).includes(:staff).limit(5)
    @new_staff_note = SponsorshipStaffNote.new(sponsorship: @sponsorship)
  end

  def download_asset
    asset = @sponsorship.asset_file
    raise ActiveRecord::RecordNotFound unless asset
    redirect_to asset.download_url()
  end

  def edit
    @sponsorship.build_alternate_billing_contact unless @sponsorship.alternate_billing_contact
    @sponsorship.build_billing_request unless @sponsorship.billing_request
    @sponsorship.build_customization_request unless @sponsorship.customization_request
    @sponsorship.build_note unless @sponsorship.note
  end

  def update
    @sponsorship.assign_attributes(sponsorship_params)
    @sponsorship.staff = current_staff
    respond_to do |format|
      if @sponsorship.save
        ProcessSponsorshipEditJob.perform_later(@sponsorship.last_editing_history)
        format.html { redirect_to conference_sponsorship_path(@conference, @sponsorship), notice: 'Sponsorship was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  def destroy
    return render(status: 404, plain: '') if @sponsorship.withdrawn?
    @sponsorship.staff = current_staff
    respond_to do |format|
      @sponsorship.withdraw
      @sponsorship.save!
      ProcessSponsorshipEditJob.perform_later(@sponsorship.last_editing_history)
      format.html { redirect_to conference_sponsorship_path(@conference, @sponsorship), notice: 'Sponsorship was successfully withdrawn.' }
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

      :suspended,
      :accepted,

      :number_of_additional_attendees,

      contact_attributes: %i(id email email_cc address organization unit name),
      alternate_billing_contact_attributes: %i(_keep id email address organization unit name),

      billing_request_attributes: %i(id body),
      customization_request_attributes: %i(id body),
      note_attributes: %i(id body),
    ).tap do |sp|
      unless sp[:alternate_billing_contact_attributes].nil? || sp[:alternate_billing_contact_attributes][:_keep] == '1'
        (sp[:alternate_billing_contact_attributes] ||= {})[:_destroy] = '1'
      end
      %i(
        billing_request_attributes
        customization_request_attributes
        note_attributes
      ).each do |k|
        unless sp.dig(k, :body).present?
          sp[k][:_destroy] = '1' if sp[k]
        end
      end
    end
  end

  def set_sponsorship
    @sponsorship = Sponsorship.find(params[:id])
    @conference = @sponsorship.conference
  end
end
