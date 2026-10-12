# typed: strict
# frozen_string_literal: true

require 'protobufable/alba_binding'

# A google.protobuf.Timestamp field refuses the ActiveSupport::TimeWithZone an Active Record column
# returns, so bound resources convert through the :timestamp type.
Protobufable::AlbaBinding.register_timestamp_type!
