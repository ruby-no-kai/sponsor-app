# typed: strict
# frozen_string_literal: true

require 'protobufable/problem'

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

  # The server failed to answer the request.
  class Internal < ApiError
    problem_type :PROBLEM_TYPE_INTERNAL
  end
end
