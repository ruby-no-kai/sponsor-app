# typed: strict
# frozen_string_literal: true

# The announcements of a conference sharing an issue: one announcement in each locale it is
# written in. Its announcements carry the columns a listing shows, not their bodies.
class AnnouncementIssue
  LISTED_COLUMNS = %i(id conference_id issue locale title stickiness revision published_at exhibitors_only).freeze #: Array[Symbol]

  # Every issue of the conference, the pinned ones first by their highest stickiness, each group then
  # newest first.
  #: (Conference) -> Array[AnnouncementIssue]
  def self.all_of(conference)
    conference.announcements.select(LISTED_COLUMNS).order(:issue, :locale).group_by(&:issue)
      .map { |issue, announcements| new(issue:, announcements:) }
      .sort_by { [-it.stickiness, -it.first_id] }
  end

  # The issue an announcement belongs to, in every locale.
  #: (Announcement) -> AnnouncementIssue
  def self.of(announcement)
    new(issue: announcement.issue, announcements: announcement.all_locales.select(LISTED_COLUMNS).order(:locale).to_a)
  end

  #: String
  attr_reader :issue

  # Ordered by locale.
  #: Array[Announcement]
  attr_reader :announcements

  #: (issue: String, announcements: Array[Announcement]) -> void
  def initialize(issue:, announcements:)
    raise ArgumentError, "the issue #{issue.inspect} has no announcement" if announcements.empty?

    @issue = issue
    @announcements = announcements
  end

  # The newest revision among the locales. A locale below it has yet to be translated.
  #: () -> Integer
  def latest_revision = Must.because(announcements.map(&:revision).max) { 'an issue has an announcement' }

  # The issue is pinned when any of its locales is.
  #: () -> Integer
  def stickiness = Must.because(announcements.map(&:stickiness).max) { 'an issue has an announcement' }

  # ID of the issue's first announcement, which orders issues by when they were started.
  #: () -> Integer
  def first_id = Must.because(announcements.map(&:id).min) { 'an issue has an announcement' }
end
