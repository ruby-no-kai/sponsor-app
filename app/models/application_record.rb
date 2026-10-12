# typed: strict
# frozen_string_literal: true

require 'protobufable/column_validatable'

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Checks every Protobufable::JsonType column against its message's buf.validate rules.
  include Protobufable::ColumnValidatable
end
