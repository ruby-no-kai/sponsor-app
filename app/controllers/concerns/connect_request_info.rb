# typed: strict
# frozen_string_literal: true

require 'google/rpc/error_details_pb'

# Adds a google.rpc.RequestInfo holding the request ID to every Connect error a controller renders,
# so an error a user reports leads to its log lines. Include after ConnectRpcRails::Controller.
#
# @requires_ancestor: ConnectRpcRails::Controller
# @requires_ancestor: ActionController::Metal
module ConnectRequestInfo
  #: (ConnectRpcRails::Error) -> void
  private def render_connect_error(error)
    request_info = Google::Rpc::RequestInfo.new(request_id: request.request_id.to_s)

    super(ConnectRpcRails::Error.new(
      error.code, error.message, details: [*error.details, Google::Protobuf::Any.pack(request_info)],
    ))
  end
end
