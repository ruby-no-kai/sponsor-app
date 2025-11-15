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

    @sponsorship = Sponsorship.new(sponsorship_params)
    return render(status: 403, plain: '403') if sponsorship_params[:asset_file_id].present? && (!session[:asset_file_ids] || !session[:asset_file_ids].include?(@sponsorship.asset_file&.id))

    if sponsorship_params[:asset_file_id_to_copy].present? && !@sponsorship.asset_file
      src_asset = SponsorshipAssetFile.where(sponsorship_id: current_available_sponsorships.map(&:id), id: sponsorship_params[:asset_file_id_to_copy]).first
      @sponsorship.asset_file = src_asset.copy_to!(@conference)
    end

    @sponsorship.locale = I18n.locale
    @sponsorship.conference = @conference
    @sponsorship.assume_organization
    @sponsorship.accept if @sponsorship.plan&.auto_acceptance

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
    return {} unless session[:sponsorship_ids].include?(params[:sponsorship_id_to_copy].to_i)
    src = Sponsorship.find_by(id: params[:sponsorship_id_to_copy])
    return {} unless src
    {
      name: src.name,
      url: src.url,
      profile: src.profile,
      asset_file_id_to_copy: src.asset_file_id,
      contact_attributes: src.contact.attributes.except('id', 'kind'),
      alternate_billing_contact_attributes: src.alternate_billing_contact&.attributes&.except('id', 'kind')&.merge(_keep: '1'),
      billing_request_attributes: src.billing_request&.attributes&.except('id', 'kind'),
    }.compact
  end
end
