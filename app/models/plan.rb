class Plan < ApplicationRecord
  belongs_to :conference
  validates :name, presence: true

  def booth_applicable?
    booth_size > 0
  end
end
