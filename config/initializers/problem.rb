# typed: strict
# frozen_string_literal: true

require 'google/rpc/error_details_pb'

# Answers an exception escaping a Connect call outside any controller's rescue in the Connect error
# shape, with the request ID beside the error. Every other request gets the static error pages.
class ConnectExceptions < ConnectRpcRails::ExceptionsApp
  #: (Exception, Hash[String, untyped]) -> ConnectRpcRails::Error
  private def connect_error_for(exception, env)
    error = exception.is_a?(Problem::Detailable) ? problem_error_for(exception) : super
    request_info = Google::Rpc::RequestInfo.new(request_id: env['action_dispatch.request_id'].to_s)

    ConnectRpcRails::Error.new(
      error.code, error.message, details: [*error.details, Google::Protobuf::Any.pack(request_info)],
    )
  end

  # The answer Protobufable::Connect::ProblemRescuable gives a problem raised inside a controller.
  #: (Exception & Problem::Detailable) -> ConnectRpcRails::Error
  private def problem_error_for(exception)
    problem = exception.to_problem
    information = exception.is_a?(Protobufable::Problem::Information) ? exception.problem_information : []
    details = Protobufable::ProblemDetails.new(
      type: problem.type || '',
      title: problem.title || '',
      status: problem.status,
      detail: problem.detail || '',
      instance: problem.instance || '',
      information: information.map { Google::Protobuf::Any.pack(it) },
    )

    ConnectRpcRails::Error.new(
      ConnectRpcRails::Error.code_for_http_status(problem.status),
      problem.detail.presence || problem.title,
      details: [Google::Protobuf::Any.pack(details)],
    )
  end
end

Rails.application.configure do
  # Problem types are identifiers rather than links, so every environment publishes the production
  # host's.
  config.problem.type_prefix = 'https://sponsorships.rubykaigi.org/problems/'
  config.exceptions_app = ConnectExceptions.new(ActionDispatch::PublicExceptions.new(Rails.public_path))
end
