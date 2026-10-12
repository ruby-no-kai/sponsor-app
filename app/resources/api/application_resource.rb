# typed: strict
# frozen_string_literal: true

require 'protobufable/alba_binding'

module Api
  # Base of the resources that build the API's messages. Each binds to a message with
  # `with_protobuf`, which raises at load time when the two disagree on a field.
  class ApplicationResource
    include Alba::Resource
    include Protobufable::AlbaBinding
  end
end
