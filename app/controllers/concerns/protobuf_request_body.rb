# typed: strict
# frozen_string_literal: true

require 'active_support/concern'
require 'protobufable/protovalidate'

# Decodes a JSON request body into the message an action declares with `protobuf_body`, and checks it against
# the message's buf.validate rules before the action runs. A body that does not decode, that breaks a rule, or
# that the action rejects with ActionController::BadRequest, is answered 400 with `{"error": reason}`.
# @requires_ancestor: ApplicationController
module ProtobufRequestBody
  extend ActiveSupport::Concern
  include Protobufable::RequestValidatable

  included do
    rescue_from ActionDispatch::Http::Parameters::ParseError, ActionController::BadRequest, with: :render_bad_request
    rescue_from Protobufable::RequestValidatable::InvalidMessage, with: :render_invalid_message
  end

  #: (ActionDispatch::Http::Parameters::ParseError | ActionController::BadRequest) -> void
  private def render_bad_request(error)
    # The decoder's error names the field at fault, which Rails' ParseError does not.
    render_reason((error.cause || error).message)
  end

  # Names each violated field by its .proto name, as the editor sends them.
  #: (Protobufable::RequestValidatable::InvalidMessage) -> void
  private def render_invalid_message(error)
    reason = error.violations.map do |violation|
      path = Protobufable::FieldPath.render(violation.field, error.message_class)
      path.empty? ? violation.message : "#{path}: #{violation.message}"
    end
    render_reason(reason.join('; '))
  end

  # A reason can quote the body's bytes, which need not be UTF-8.
  #: (String) -> void
  private def render_reason(reason)
    render status: :bad_request, json: {error: String.new(reason, encoding: Encoding::UTF_8).scrub}
  end
end
