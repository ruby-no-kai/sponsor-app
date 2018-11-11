class Plan < ApplicationRecord
  belongs_to :conference
  validates :name, presence: true
  validates :price_text, presence: true

  def booth_eligible?
    booth_size > 0
  end

  def words_limit_hard
    # TODO:
    (words_limit || 0) * 1.1
  end
end
