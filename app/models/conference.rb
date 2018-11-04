class Conference < ApplicationRecord
  has_many :form_descriptions, dependent: :destroy
  has_many :plans, dependent: :destroy
end
