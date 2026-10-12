# typed: strict
# frozen_string_literal: true

require 'protobufable/connect'

module Api
  # Base of the controllers serving the Connect services in proto/, one action per RPC.
  #
  # Each RPC is declared with a policy right above its definition, `authorize :name`, chosen from
  # the policies its service's base controller enforces. Calling an RPC that declares none raises.
  class ApplicationController < ActionController::API
    include ConnectRpcRails::Controller
    include Protobufable::Connect::ProblemRescuable
    include ActionController::Cookies
    include ConnectForgeryProtection
    include ConnectRequestInfo
    include LocaleSelectable

    # Raised when a controller serves an RPC whose policy it never declared.
    class UndeclaredPolicy < StandardError; end

    wrap_parameters false

    before_action :verify_connect_request_origin!
    before_action :set_locale
    before_action :populate_sentry_scope
    before_action :authenticate_rpc!
    before_action :authorize_rpc!

    @rpc_policies = nil #: Hash[String, Symbol]?
    @pending_rpc_policy = nil #: Symbol?

    # The policies this service's RPCs choose from.
    #: () -> Array[Symbol]
    def self.rpc_policy_names = []

    # Declares the policy the RPC defined next in this controller is served under.
    #: (Symbol) -> void
    def self.authorize(policy)
      unless rpc_policy_names.include?(policy)
        raise ArgumentError, "#{name} has no policy #{policy.inspect}, only #{rpc_policy_names.inspect}"
      end
      if (pending = @pending_rpc_policy)
        raise ArgumentError, "#{name} declares #{pending.inspect} for no RPC"
      end

      @pending_rpc_policy = policy
    end

    # The policy declared for an RPC action of this controller.
    #: (String) -> Symbol?
    def self.rpc_policy(action) = rpc_policies[action]

    #: () -> Hash[String, Symbol]
    def self.rpc_policies = (@rpc_policies ||= {})

    # Binds the pending policy to the RPC just defined.
    #: (Symbol) -> void
    def self.method_added(method_name)
      super

      action = method_name.to_s
      policy = @pending_rpc_policy
      unless connect_rpcs&.key?(action)
        raise ArgumentError, "#{name} declares #{policy.inspect} for #{action}, which is not an RPC" if policy

        return
      end
      return unless policy

      @pending_rpc_policy = nil
      rpc_policies[action] = policy
    end

    # TODO: consolidate with root ApplicationController to eliminate duplicates
    #: () -> Staff?
    private def current_staff_maybe
      return @current_staff if defined?(@current_staff)

      staff_id = session[:staff_id]
      @current_staff = (Staff.find_by(id: staff_id) if staff_id) #: Staff?
    end

    #: () -> Staff
    private def current_staff = Must.because(current_staff_maybe) { 'the RPC policy requires a staff session' }

    # The policy of the RPC this request runs, or nil for a request that runs no RPC action: the
    # catch-all for undeclared methods, or an RPC this controller does not implement.
    #: () -> Symbol?
    private def rpc_policy
      return unless self.class.connect_rpcs&.key?(action_name) && action_methods.include?(action_name)

      self.class.rpc_policy(action_name) ||
        raise(UndeclaredPolicy, "#{self.class.name}##{action_name} serves an RPC with no `authorize` policy")
    end

    #: () -> void
    private def authenticate_rpc! = require_session!(rpc_policy)

    #: () -> void
    private def authorize_rpc! = enforce_policy!(rpc_policy)

    # Raises a problem when the policy needs a session this request lacks.
    #: (Symbol?) -> void
    private def require_session!(_policy)
      raise NotImplementedError, "#{self.class.name} enforces no session requirement"
    end

    # Raises a problem when the session may not run this RPC.
    #: (Symbol?) -> void
    private def enforce_policy!(_policy)
      raise NotImplementedError, "#{self.class.name} enforces no policy"
    end

    # A classified exception's message can quote internals, so only the status text goes out.
    #: (Exception) -> ConnectRpcRails::Error
    private def connect_error_for(exception)
      error = super
      return error if exception.is_a?(ConnectRpcRails::Error) || exception.is_a?(Problem::Detailable)

      message = Rack::Utils::HTTP_STATUS_CODES.fetch(error.http_status) { error.code.to_s }
      ConnectRpcRails::Error.new(error.code, message, details: error.details)
    end

    # rescue_from swallows the problem before Sentry's middleware sees it, and Sentry does not
    # subscribe to the Rails error reporter here.
    #: (Exception, Problem::Details) -> void
    private def report_problem(error, problem)
      super
      Sentry.capture_exception(error)
    end

    #: () -> void
    private def populate_sentry_scope
      staff = current_staff_maybe
      return unless staff

      Sentry.configure_scope do |scope|
        scope.set_context('sponsor-app.staff', {id: staff.id, login: staff.login})
      end
      Sentry.set_user(id: "staff_#{staff.id}", username: staff.login)
    end
  end
end
