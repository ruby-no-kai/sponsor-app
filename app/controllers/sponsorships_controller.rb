class SponsorshipsController < ApplicationController
  def show
    unless current_sponsorship
      return redirect_to new_user_conference_sponsorship_path(conference: @conference)
    end
    @sponsorship = current_sponsorship
    @conference = current_sponsorship&.conference
    raise ActiveRecord::RecordNotFound unless @conference

    @announcements = @sponsorship.conference.announcements
      .where(locale: I18n.locale)
      .where('published_at IS NOT NULL')
      .order('stickiness DESC, id DESC')
      .merge(@sponsorship.exhibitor? ? Announcement.for_exhibitors : Announcement.for_sponsors)
  end

  def edit
    @sponsorship = current_sponsorship
    @conference = current_sponsorship&.conference
    raise ActiveRecord::RecordNotFound if !@conference&.amendment_open? && !current_staff

    @sponsorship.build_nested_attributes_associations
  end

  def new
    return render(status: 404, plain: '404') if current_sponsorship

    @conference = Conference.find_by!(slug: params[:conference_slug])
    return render(plain: '404', status: 404) unless @conference.verify_invite_code(params[:invite_code])
    return render(:closed, status: 403) if !@conference&.application_open? && !current_staff

    @sponsorship = Sponsorship.new(copied_sponsorship_attributes)
    @sponsorship.conference = @conference
    @sponsorship.build_nested_attributes_associations
  end

  def create
    return render(status: 404, plain: '404') if current_sponsorship

    @conference = Conference.find_by!(slug: params[:conference_slug])
    return render(plain: '404', status: 404) unless @conference.verify_invite_code(params[:invite_code])
    return render(:closed, status: 403) if !@conference&.application_open? && !current_staff

    @sponsorship = Sponsorship.new(sponsorship_params.except(:asset_file_id))

    if sponsorship_params[:asset_file_id].present? 
      asset_src = SponsorshipAssetFile
        .available_for_user(
          sponsorship_params[:asset_file_id],
          session_asset_file_ids: session[:asset_file_ids],
          available_sponsorship_ids: current_available_sponsorships&.pluck(:id) || [],
        )
        .first
      return render(plain: '404 asset not found', status: 404) unless asset_src
      if asset_src.sponsorship_id.present?
        new_asset = asset_src.copy_to!(@conference)
        (session[:asset_file_ids] ||= []) << new_asset.id
        @sponsorship.asset_file = new_asset
      else
        @sponsorship.asset_file = asset_src
      end
    end

    @sponsorship.locale = I18n.locale
    @sponsorship.conference = @conference
    @sponsorship.assume_organization
    @sponsorship.accept if @sponsorship.plan&.auto_acceptance && !@sponsorship.organization&.auto_acceptance_disabled

    respond_to do |format|
      if @sponsorship.save(context: :update_by_user)
        (session[:sponsorship_ids] ||= []).unshift @sponsorship.id
        session[:asset_file_ids]&.delete(@sponsorship.asset_file.id)
        SponsorshipWelcomeJob.perform_later(@sponsorship)
        format.html { redirect_to user_conference_sponsorship_path(conference: @conference), notice: t('.notice') }
      else
        @sponsorship.build_nested_attributes_associations
        format.html { render :new }
      end
    end
  end

  def update
    @sponsorship = current_sponsorship
    @conference = current_sponsorship&.conference
    raise ActiveRecord::RecordNotFound unless @conference&.amendment_open?

    sp = sponsorship_params
    sp.delete(:asset_file_id) if @sponsorship.asset_file_id
    @sponsorship.assign_attributes(sp)
    @sponsorship.locale = I18n.locale

    respond_to do |format|
      if @sponsorship.save(context: :update_by_user)
        ProcessSponsorshipEditJob.perform_later(@sponsorship.last_editing_history)
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
      :asset_file_id,
      :asset_file_id_to_copy,
      :booth_requested,
      :fallback_option,
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

  def copied_sponsorship_attributes
    return {} unless params[:sponsorship_id_to_copy].present?
    return {} unless session[:sponsorship_ids]&.include?(params[:sponsorship_id_to_copy].to_i)
    src = Sponsorship.find_by(id: params[:sponsorship_id_to_copy])
    return {} unless src
    src.attributes_for_copy
  end
end
