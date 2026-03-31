# frozen_string_literal: true

module Admin
  class ExpenseFilesController < Admin::ApplicationController
    include AssetFileSessionable

    before_action :set_conference
    before_action :set_sponsorship
    before_action :set_asset_file, only: [:show, :update, :destroy, :initiate_update]

    def create
      @asset_file = ExpenseFile.prepare(conference: @conference, sponsorship: @sponsorship)
      @asset_file.assign_attributes(params.permit(:filename, :content_type))
      @asset_file.save!
      render json: make_session
    end

    def show
      redirect_to @asset_file.download_url(disposition: :inline), allow_other_host: true
    end

    def update
      @asset_file.assign_attributes(params.permit(:filename, :content_type))
      @asset_file.status = 'uploaded'
      super
    end

    def destroy
      @asset_file.destroy!
      render json: {ok: true}
    end

    def initiate_update
      render json: make_session
    end

    private def set_conference
      @conference = Conference.find_by!(slug: params[:conference_slug])
      check_staff_conference_authorization!(@conference)
    end

    private def set_sponsorship
      @sponsorship = Sponsorship.where(conference: @conference).find(params[:sponsorship_id])
    end

    private def set_asset_file
      @asset_file = @sponsorship.expense_files.find(params[:id])
    end

    private def asset_file_report_to_url(asset_file)
      conference_sponsorship_expense_file_path(@conference, @sponsorship, asset_file)
    end
  end
end
