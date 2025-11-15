# Cached Tito 'release' object (ticket kind) for a conference.
class TitoCachedRelease < ApplicationRecord
  belongs_to :conference

  validates :tito_release_slug, presence: true, uniqueness: { scope: :conference_id }
  validates :tito_release_id, presence: true, uniqueness: { scope: :conference_id }
end
