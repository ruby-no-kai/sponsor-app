# frozen_string_literal: true

class ExhibitionEditingHistory < ApplicationRecord
  include EditingHistory
  belongs_to :exhibition

  def target
    exhibition
  end
end
