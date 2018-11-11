class Admin::SponsorshipEditingHistoriesController < Admin::ApplicationController
  def index
    @sponsorship = Sponsorship.find(params[:sponsorship_id])
    @conference = @sponsorship.conference
    @editing_histories = @sponsorship.editing_histories
  end
end
