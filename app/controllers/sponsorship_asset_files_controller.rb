class SponsorshipAssetFilesController < ApplicationController
  def create
    return render(status: 403, json: {error: 403}) if current_sponsorship&.asset_file
    conference = Conference.find(params[:conference_id])
    return render(status: 403, json: {error: 403}) unless conference&.amendment_open?

    asset_file = SponsorshipAssetFile.create!(prefix: "#{conference.id}/", extension: params[:extension])
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
