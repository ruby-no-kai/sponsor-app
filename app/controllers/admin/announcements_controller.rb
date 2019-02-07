class Admin::AnnouncementsController < Admin::ApplicationController
  before_action :set_conference
  before_action :set_announcement, only: %i(show edit update destroy)

  def index
    @announcements = @conference.announcements
      .order('issue ASC, id ASC')
      .select(:id, :conference_id, :issue, :locale, :title, :stickiness, :revision, :staff_id, :published_at, :exhibitors_only)
      .to_a.group_by(&:issue)
      .sort_by { |issue, locales| [-locales.max_by(&:stickiness).stickiness, -locales.min_by(&:id).id] }
  end

  def new
    @announcement = Announcement.new(conference: @conference)
    if params[:issue].present?
      @announcement.issue = params[:issue]
      # locales = @conference.announcements
      #   .where(issue: @announcement.issue)
      #   .select(:id, :conference_id, :issue, :locale, :title, :published_at)
    end
  end

  def create
    @announcement = Announcement.new(announcement_params)
    @announcement.conference = @conference
    @announcement.staff = current_staff

    respond_to do |format|
      if @announcement.save
        format.html do
          redirect_to conference_announcement_path(@conference, @announcement)
        end
      else
        format.html do
          render :new
        end
      end
    end
  end

  def show
    @locales = @announcement.all_locales
      .select(:id, :conference_id, :issue, :locale, :title, :published_at)
  end

  def edit
  end

  def update
    a_params = announcement_params.except(:issue)
    respond_to do |format|
      if @announcement.update(a_params)
        format.html { redirect_to conference_announcement_path(@conference, @announcement), notice: 'Announcement was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  private

  def set_announcement
    issue, locale = params[:id]&.split(':', 2)
    @announcement = @conference.announcements.find_by!(issue: issue, locale: locale)
  end

  def set_conference
    @conference = Conference.find_by!(slug: params[:conference_slug])
  end

  def announcement_params
    params.require(:announcement).permit(
      :issue,
      :locale,
      :title,
      :body,
      :stickiness,
      :published,
      :new_revision,
      :exhibitors_only,
    )
  end
end
