# frozen_string_literal: true

class Announcement < ApplicationRecord
  include MarkdownBody

  belongs_to :staff
  belongs_to :conference

  validates :issue, presence: true
  validates :locale, presence: true
  validates :title, presence: true
  validates :body, presence: true

  before_validation :generate_issue
  before_validation :bump_revision

  scope :for_sponsors, -> { where(exhibitors_only: false) }
  scope :for_exhibitors, -> { where('1=1') }

  def to_param
    "#{issue}:#{locale}"
  end

  def all_locales
    conference.announcements.where(issue: issue)
  end

  def generate_issue
    if conference && !persisted? && issue.blank?
      loop do
        self.issue = SecureRandom.urlsafe_base64(8)
        break unless self.class.where(conference: conference, issue: issue).exists?
      end
    end
  end

  def bump_revision
    unless will_save_change_to_revision?
      self.revision = latest_revision
    end
  end

  def published=(flag)
    flag = flag == '1' if flag.is_a?(String)
    case
    when flag && !published_at
      self.published_at = Time.zone.now
    when flag && published_at
      # do nothing
    when !flag
      self.published_at = nil
    end
    flag # rubocop:disable Lint/Void
  end

  def published
    !!published_at
  end
  alias_method :published?, :published

  def draft?
    !published?
  end

  def pin?
    stickiness > 0
  end

  def new_revision=(flag)
    flag = flag == '1' if flag.is_a?(String)
    self.revision = if flag
      (revision_was || 0) + 1
    else
      revision_was || 0
    end
  end

  def new_revision
    revision_changed?
  end

  def latest_revision
    all_locales.group(:issue).pluck(Arel.sql('MAX(revision)'))[0] || 1
  end

  def revision_behind?
    revision < latest_revision
  end
end
