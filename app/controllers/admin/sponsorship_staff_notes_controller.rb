class Admin::SponsorshipStaffNotesController < Admin::ApplicationController
  before_action :set_staff_note, only: [:show, :edit, :update, :destroy]

  def index
    @sponsorship = Sponsorship.find(params[:sponsorship_id])
    @conference = @sponsorship.conference

    @new_staff_note = SponsorshipStaffNote.new
    @new_staff_note.sponsorship = @sponsorship
    @staff_notes = @sponsorship.staff_notes.order(stickiness: :desc, created_at: :desc).includes(:staff)
  end

  def create
    @sponsorship = Sponsorship.find(params[:sponsorship_id])
    @conference = @sponsorship.conference

    @staff_note = SponsorshipStaffNote.new(staff_note_params)
    @staff_note.staff = current_staff
    @staff_note.sponsorship = @sponsorship

    respond_to do |format|
      if @staff_note.save
        format.html do
          if params[:back_to] == 'sponsorship'
            redirect_to conference_sponsorship_path(@conference, @sponsorship)
          else
            redirect_to conference_sponsorship_staff_notes_path(@conference, @sponsorship)
          end
        end
      else
        format.html do
          index()
          @new_staff_note = @staff_note
          render :index
        end
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @staff_note.update(staff_note_params)
        format.html do
          if params[:back_to] == 'sponsorship'
            redirect_to conference_sponsorship_path(@conference, @sponsorship)
          else
            redirect_to conference_sponsorship_staff_notes_path(@conference, @sponsorship)
          end
        end
      else
        format.html do
          index()
          @new_staff_note = @staff_note
          render :index
        end
      end
    end
  end

  def destroy
    @staff_note.destroy
    respond_to do |format|
      format.html do
        if params[:back_to] == 'sponsorship'
          redirect_to conference_sponsorship_path(@conference, @sponsorship)
        else
          redirect_to conference_sponsorship_staff_notes_path(@conference, @sponsorship)
        end
      end
    end
  end

  private

  def set_staff_note
    @staff_note = SponsorshipStaffNote.find(params[:id])
    @sponsorship = @staff_note.sponsorship
    @conference = @sponsorship.conference
  end

  def staff_note_params
    params.require(:sponsorship_staff_note).permit(
      :body,
      :stickiness,
    )
  end
end
