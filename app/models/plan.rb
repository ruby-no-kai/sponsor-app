class Plan < ApplicationRecord
  belongs_to :conference
  validates :name, presence: true
  validates :conference, presence: true
end
