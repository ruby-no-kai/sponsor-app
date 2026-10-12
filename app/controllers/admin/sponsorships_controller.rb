# typed: strict
# frozen_string_literal: true

module Admin
  class SponsorshipsController < Admin::ApplicationController
    before_action :set_conference
    before_action :set_sponsorship

    #: () -> void
    def show
      @pinned_staff_notes = sponsorship.staff_notes.where('stickiness > 0').order(stickiness: :desc, created_at: :desc).includes(:staff) #: SponsorshipStaffNote::PrivateAssociationRelation?
      @staff_notes = sponsorship.staff_notes.where('stickiness = 0').order(stickiness: :desc, created_at: :desc).includes(:staff).limit(5) #: SponsorshipStaffNote::PrivateAssociationRelation?
      @new_staff_note = SponsorshipStaffNote.new(sponsorship:) #: SponsorshipStaffNote?
    end

    #: () -> void
    def download_asset
      asset = sponsorship.asset_file
      raise ActiveRecord::RecordNotFound unless asset

      redirect_to(asset.download_url, allow_other_host: true)
    end

    #: () -> void
    def edit
      sponsorship.build_alternate_billing_contact unless sponsorship.alternate_billing_contact
      sponsorship.build_billing_request unless sponsorship.billing_request
      sponsorship.build_customization_request unless sponsorship.customization_request
      sponsorship.build_note unless sponsorship.note
    end

    #: () -> void
    def update
      sponsorship.assign_attributes(sponsorship_params)
      sponsorship.staff = current_staff
      respond_to do |format|
        if sponsorship.save
          ProcessSponsorshipEditJob.perform_later(sponsorship.last_editing_history)
          format.html { redirect_to conference_sponsorship_path(conference, sponsorship), notice: 'Sponsorship was successfully updated.' }
        else
          format.html { render :edit }
        end
      end
    end

    #: () -> void
    def destroy
      return render(status: :not_found, plain: '') if sponsorship.withdrawn?

      sponsorship.staff = current_staff
      respond_to do |format|
        sponsorship.withdraw
        sponsorship.save!
        ProcessSponsorshipEditJob.perform_later(sponsorship.last_editing_history)
        format.html { redirect_to conference_sponsorship_path(conference, sponsorship), notice: 'Sponsorship was successfully withdrawn.' }
      end
    end

    #: () -> ActionController::Parameters
    private def sponsorship_params
      params.require(:sponsorship).permit(
        :plan_id,
        :name,
        :url,
        :profile,
        :logo_key,
        :booth_requested,
        :fallback_option,
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
          if sp.dig(k, :body).blank?
            sp[k][:_destroy] = '1' if sp[k]
          end
        end
      end
    end

    #: () -> void
    private def set_conference
      @conference = Conference.find_by!(slug: params[:conference_slug]) #: Conference?
      check_staff_conference_authorization!(conference)
    end

    #: () -> void
    private def set_sponsorship
      @sponsorship = Sponsorship.where(conference:).find(params[:id]) #: Sponsorship?
    end

    #: () -> Conference
    private def conference = Must.because(@conference) { "set_conference runs before every action" }

    #: () -> Sponsorship
    private def sponsorship = Must.because(@sponsorship) { "set_sponsorship runs before every action" }
  end
end
