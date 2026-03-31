# frozen_string_literal: true

class ExpenseFileResource
  include Alba::Resource

  attributes :id, :filename, :content_type, :created_at
end
