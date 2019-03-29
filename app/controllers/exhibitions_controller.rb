class ExhibitionsController < ApplicationController
  before_action :require_sponsorship_session

  def new
    return render(status: 404, plain: '404') if current_sponsorship.exhibition
    return render(status: 404, plain: '404') unless current_sponsorship.booth_assigned?
    @exhibition = Exhibition.new(sponsorship: current_sponsorship)
  end

  def create
    return render(status: 404, plain: '404') unless current_sponsorship.booth_assigned?

    @exhibition = Exhibition.new(exhibition_params)
    @exhibition.sponsorship = current_sponsorship

    if @exhibition.save
      redirect_to user_conference_sponsorship_path(), notice: t('.notice')
    else
      render :new
    end
  end

  def edit
    raise ActiveRecord::RecordNotFound if !current_sponsorship.conference.amendment_open? && !current_staff

    @exhibition = current_sponsorship.exhibition
    raise ActiveRecord::RecordNotFound unless @exhibition
  end

  def update
    raise ActiveRecord::RecordNotFound if !current_sponsorship.conference.amendment_open? && !current_staff

    @exhibition = current_sponsorship.exhibition
    raise ActiveRecord::RecordNotFound unless @exhibition
    if @exhibition.update_attributes(exhibition_params)
      redirect_to user_conference_sponsorship_path(), notice: t('.notice')
    else
      render :edit
    end
  end

  private def exhibition_params
    params.require(:exhibition).permit(
      :description,
    )
  end
end
