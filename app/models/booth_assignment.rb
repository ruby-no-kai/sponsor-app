# typed: strict
# frozen_string_literal: true

# Which sponsorships of a conference hold a booth, and which could. Booth sizes are those of the
# sponsorships' plans.
class BoothAssignment
  # Raised for sponsorship IDs the conference does not have.
  class UnknownSponsorships < StandardError
    #: Array[Integer]
    attr_reader :ids

    #: (Array[Integer]) -> void
    def initialize(ids)
      @ids = ids
      super("no sponsorship #{ids.join(', ')}")
    end
  end

  # Raised for sponsorship IDs that would give a booth to a sponsorship that is not active.
  class InactiveSponsorships < StandardError
    #: Array[Integer]
    attr_reader :ids

    #: (Array[Integer]) -> void
    def initialize(ids)
      @ids = ids
      super("inactive sponsorship #{ids.join(', ')}")
    end
  end

  #: Conference
  attr_reader :conference

  #: (Conference) -> void
  def initialize(conference)
    @conference = conference
    @candidates = nil #: Array[Sponsorship]?
  end

  # Active sponsorships that asked for a booth or hold one, largest booth first, then by name.
  #: () -> Array[Sponsorship]
  def candidates
    @candidates ||= conference.sponsorships.active
      .eager_load(:plan).preload(:organization)
      .where(Sponsorship.arel_table[:booth_requested].eq(true).or(Sponsorship.arel_table[:booth_assigned].eq(true)))
      .order(Plan.arel_table[:booth_size].desc.nulls_last, name: :asc, id: :asc)
      .to_a
  end

  #: () -> Integer
  def candidate_count = candidates.size

  #: () -> Integer
  def candidate_booth_size = candidates.sum { it.booth_size || 0 }

  # Sponsorships that asked for a booth and have not withdrawn, accepted or not.
  #: () -> Integer
  def requesting_count = conference.sponsorships.not_withdrawn.where(booth_requested: true).count

  #: () -> Array[Sponsorship]
  def assigned = candidates.select(&:booth_assigned?)

  #: () -> Integer
  def assigned_count = assigned.size

  #: () -> Integer
  def assigned_booth_size = assigned.sum(&:assigned_booth_size)

  # Assigns booths to exactly the sponsorships the IDs name and takes them back from every other
  # sponsorship of the conference, all or nothing. A sponsorship that is not active may keep a booth
  # but not gain one. Each sponsorship it changes is saved as an edit by the staff member, and
  # ProcessSponsorshipEditJob runs for it once the change has committed.
  #: (Array[Integer], staff: Staff) -> void
  def assign!(sponsorship_ids, staff:)
    histories = Sponsorship.transaction do
      sponsorships = conference.sponsorships.order(:id).lock.to_a
      unknown_ids = sponsorship_ids - sponsorships.map(&:id)
      raise UnknownSponsorships, unknown_ids unless unknown_ids.empty?

      inactive_ids = sponsorships.reject { it.active? || it.booth_assigned? }.map(&:id) & sponsorship_ids
      raise InactiveSponsorships, inactive_ids unless inactive_ids.empty?

      sponsorships.filter_map do |sponsorship|
        sponsorship.booth_assigned = sponsorship_ids.include?(sponsorship.id)
        next unless sponsorship.booth_assigned_changed?

        sponsorship.staff = staff
        # A booth is assigned whatever else of the sponsorship fails today's validations.
        sponsorship.save!(validate: false)
        Must.be_a(sponsorship.last_editing_history, SponsorshipEditingHistory)
      end
    end #: Array[SponsorshipEditingHistory]
    @candidates = nil

    histories.each { ProcessSponsorshipEditJob.perform_later(it) }
  end
end
