class Ticket < ApplicationRecord
  CODE_CHARS = [*('A'..'Z'), *('0'..'9')] - %w(0 1 O L I K F)

  belongs_to :conference
  belongs_to :sponsorship

  enum kind: %i(attendee booth_staff)

  scope :checked_in, -> { where.not(checked_in_at: nil) }
  scope :unused, -> { where(checked_in_at: nil) }

  validates :kind, presence: true
  validates :code, presence: true
  validates :name, presence: true

  validate :check_availability
  validate :validate_correct_sponsorship
  validate :deny_multiple_entry

  before_validation :assume_conference
  before_validation :generate_code
  before_validation :generate_handle

  def to_param
    "#{conference_id}-#{code}"
  end

  def as_json
    {
      id: id,
      code: code,
      kind: kind,
      name: name,
      sponsor: sponsorship&.name,
      conference: conference&.name,
    }
  end

  def checked_in?
    !!checked_in_at
  end

  def do_check_in(authorized: false)
    self.authorized = authorized
    self.checked_in_at = Time.zone.now
  end

  def check_in(**kwargs)
    do_check_in(**kwargs)
    save
  end

  def check_in!(**kwargs)
    do_check_in(**kwargs)
    save!
  end

  private def assume_conference
    self.conference ||= sponsorship.conference if sponsorship
  end

  private def generate_code
    if code.blank?
      begin
        self.code = 8.times.map { |_| CODE_CHARS[SecureRandom.random_number(CODE_CHARS.size)] }.join
      end while self.class.where(conference: self.conference, code: self.code).exists?
    end
  end

  private def generate_handle
    if self.handle.blank?
      begin
        self.handle = SecureRandom.urlsafe_base64(64)
      end while self.class.where(conference: conference, handle: self.handle).exists?
    end
  end

  private def check_availability
    return if !checked_in_at_changed? || !checked_in_at_was.nil?
    total = case kind
            when 'attendee'
              sponsorship.total_number_of_attendees
            when 'booth_staff'
              sponsorship.booth_assigned? ? 4 : 0 # FIXME:
            end
    used = sponsorship.tickets.where(kind: kind).checked_in.count
    if used >= total
      errors.add :base, "ticket is out of stock"
    end
  end

  private def validate_correct_sponsorship
    if sponsorship && sponsorship.conference_id != self.conference_id
      errors.add :plan, "can't belong to a sponsorship for an another conference"
    end
  end

  private def deny_multiple_entry
    if checked_in_at_changed? && !checked_in_at_was.nil?
      errors.add :base, "already checked in"
    end
  end
end
