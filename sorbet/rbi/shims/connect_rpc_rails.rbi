# typed: true

# ConnectRpcRails.install! includes the routes DSL into the mapper at boot.
class ActionDispatch::Routing::Mapper
  include ConnectRpcRails::Routing
end

# A `connect_service` block is evaluated by MethodMapping, which tapioca cannot see.
module ConnectRpcRails::Routing
  sig do
    params(
      mapping: T.any(String, Symbol, T::Hash[T.any(String, Symbol), T.any(String, Symbol)]),
      block: T.nilable(T.proc.bind(ConnectRpcRails::Routing::MethodMapping).void),
    ).void
  end
  def connect_service(mapping, &block); end
end

class ConnectRpcRails::Routing::MethodMapping
  sig { params(mapping: T::Hash[T.any(String, Symbol), T.any(String, Symbol)]).void }
  def rpc(mapping); end
end
