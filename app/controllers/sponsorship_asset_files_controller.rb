class SponsorshipAssetFilesController < ApplicationController
  def show
    asset = current_sponsorship&.asset_file
    raise ActiveRecord::RecordNotFound unless asset
    redirect_to asset.download_url()
  end

  def create
    return render(status: 403, json: {error: 403}) if current_sponsorship&.asset_file
    conference = current_sponsorship ? current_sponsorship.conference : Conference.find_by!(slug: params[:conference_slug])
    return render(status: 403, json: {error: 403}) if !conference&.amendment_open? && !current_staff

    asset_file = SponsorshipAssetFile.create!(prefix: "c-#{conference.id}/", extension: params[:extension])
    (session[:asset_file_ids] ||= []) << asset_file.id
    render json: asset_file.make_session
  end

  def update
    return render(status: 401, json: {error: 401}) unless current_sponsorship
    return render(status: 404, json: {error: 404}) unless current_sponsorship.asset_file
    asset_file = current_sponsorship.asset_file
    asset_file.update!(extension: params[:extension])
    render json: current_sponsorship.asset_file.make_session
  end
end
