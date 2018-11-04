class Conference < ApplicationRecord
  has_many :form_descriptions, dependent: :destroy
end
