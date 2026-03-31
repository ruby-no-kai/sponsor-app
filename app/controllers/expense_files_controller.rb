# frozen_string_literal: true

class ExpenseFilesController < ApplicationController
  include AssetFileSessionable

  before_action :require_sponsorship_session
  before_action :set_conference
  before_action :set_asset_file, only: [:show, :update, :destroy, :initiate_update]

  def create
    @asset_file = ExpenseFile.prepare(conference: @conference, sponsorship: current_sponsorship)
    @asset_file.save!
    render json: make_session
  end

  def show
    redirect_to @asset_file.download_url, allow_other_host: true
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
    @conference = current_conference
  end

  private def set_asset_file
    @asset_file = current_sponsorship.expense_files.find(params[:id])
  end

  private def asset_file_report_to_url(asset_file)
    user_conference_expense_file_path(@conference, asset_file)
  end
end
