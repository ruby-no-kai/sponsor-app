# cache of 'source' object on Tito
class TitoSource < ApplicationRecord
  belongs_to :conference
  belongs_to :sponsorship, optional: true

  validates :tito_source_id, presence: true, uniqueness: { scope: :conference_id }

  def code
    sponsorship&.tito_source_code # XXX: Store as a column?
  end
end
