# typed: strict
# frozen_string_literal: true

require 'connect_rpc_rails/protovalidate'
require 'google/rpc/error_details_pb'
require 'protobufable/problem'
require 'protobufable/problem/information'

module Errors
  # An error the API answers as a problem, typed by a value of the ProblemType enum in
  # proto/rubykaigi/sponsor_app/problem.proto.
  class ApiError < StandardError
    include Protobufable::Problem::Typeable

    #: () -> String
    def self.problem_type_enum = 'rubykaigi.sponsor_app.ProblemType'

    #: () -> String
    def self.problem_type_annotation = 'rubykaigi.sponsor_app.problem_type'
  end

  # The request carries no valid session.
  class Unauthenticated < ApiError
    problem_type :PROBLEM_TYPE_UNAUTHENTICATED
  end

  # The session may not act on the resource the request names.
  class PermissionDenied < ApiError
    problem_type :PROBLEM_TYPE_PERMISSION_DENIED
  end

  # The resource the request names does not exist.
  class NotFound < ApiError
    problem_type :PROBLEM_TYPE_NOT_FOUND
  end

  # The request conflicts with the current state of the resource.
  class Conflict < ApiError
    problem_type :PROBLEM_TYPE_CONFLICT
  end

  # The resource is not in a state that allows the request.
  class FailedPrecondition < ApiError
    problem_type :PROBLEM_TYPE_FAILED_PRECONDITION
  end

  # The record the request would save fails validation.
  #
  # An error on an attribute that the request's Input message declares as a field is published as a
  # google.rpc.BadRequest violation of that field. Any other error, :base included, names no field
  # and concerns the request as a whole.
  class InvalidRecord < ApiError
    include Protobufable::Problem::Information

    problem_type :PROBLEM_TYPE_INVALID_RECORD

    # field_prefix is the path of the Input within the request, such as "input". With json_names,
    # fields are spelled as ProtoJSON spells them, for a request that came in as JSON.
    #: (record: ActiveRecord::Base, ?input_class: singleton(Google::Protobuf::AbstractMessage)?,
    #|  ?field_prefix: String, ?json_names: bool) -> void
    def initialize(record:, input_class: nil, field_prefix: '', json_names: false)
      @record = record #: ActiveRecord::Base
      @input_class = input_class #: singleton(Google::Protobuf::AbstractMessage)?
      @field_prefix = field_prefix #: String
      @json_names = json_names #: bool
      super(detail: record.errors.full_messages.join('; '))
    end

    #: () -> Array[untyped]
    def problem_information
      super + [Google::Rpc::BadRequest.new(field_violations:)]
    end

    #: () -> Array[Google::Rpc::BadRequest::FieldViolation]
    private def field_violations
      @record.errors.map do |error|
        field = field_path(error.attribute)
        Google::Rpc::BadRequest::FieldViolation.new(
          field: field || '',
          description: field ? error.message : error.full_message,
          reason: ConnectRpcRails::MessageValidatable.reason(error.type.to_s),
        )
      end
    end

    # The Input field an attribute of the same name maps to, or nil when the Input has none.
    #: (Symbol) -> String?
    private def field_path(attribute)
      return if attribute == :base

      field = @input_class&.descriptor&.lookup(attribute.to_s)
      return unless field

      name = @json_names ? field.json_name : field.name
      @field_prefix.empty? ? name : "#{@field_prefix}.#{name}"
    end
  end

  # The server failed to answer the request.
  class Internal < ApiError
    problem_type :PROBLEM_TYPE_INTERNAL
  end
end
