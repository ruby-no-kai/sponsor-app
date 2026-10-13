# typed: strict
# frozen_string_literal: true

module Admin
  class ExpenseFilesController < Admin::ApplicationController
    include AssetFileSessionable

    before_action :set_conference
    before_action :set_sponsorship
    before_action :set_asset_file, only: [:show, :update, :destroy, :initiate_update]

    #: () -> void
    def create
      @asset_file = ExpenseFile.prepare(conference:, sponsorship:)
      @asset_file.assign_attributes(params.permit(:filename, :content_type))
      @asset_file.save!
      render proto_json: make_session
    end

    #: () -> void
    def show
      redirect_to asset_file.download_url(disposition: :inline), allow_other_host: true
    end

    #: () -> void
    def update
      asset_file.assign_attributes(params.permit(:filename, :content_type))
      asset_file.status = 'uploaded'
      super
    end

    #: () -> void
    def destroy
      asset_file.destroy!
      render json: {ok: true}
    end

    #: () -> void
    def initiate_update
      asset_file.content_type = params[:content_type] if params[:content_type].present?
      render proto_json: make_session
    end

    #: () -> void
    private def set_conference
      @conference = Conference.find_by!(slug: params[:conference_slug]) #: Conference?
      check_staff_conference_authorization!(conference)
    end

    #: () -> void
    private def set_sponsorship
      @sponsorship = Sponsorship.where(conference:).find(params[:sponsorship_id]) #: Sponsorship?
    end

    #: () -> void
    private def set_asset_file
      @asset_file = sponsorship.expense_files.find(params[:id]) #: ExpenseFile?
    end

    #: () -> Conference
    private def conference = Must.because(@conference) { "set_conference runs before every action" }

    #: () -> Sponsorship
    private def sponsorship = Must.because(@sponsorship) { "set_sponsorship runs before every action" }

    #: () -> ExpenseFile
    private def asset_file = Must.because(@asset_file) { "set_asset_file or create assigns @asset_file" }

    #: (ExpenseFile) -> String
    private def asset_file_report_to_url(asset_file)
      conference_sponsorship_expense_file_path(conference, sponsorship, asset_file)
    end
  end
end
