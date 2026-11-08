# typed: strict
# frozen_string_literal: true

# Rejects a Connect call that another site's page could have made a browser send with the viewer's
# cookies.
#
# A POST must carry Connect-Protocol-Version, which a page on another origin can set only after a
# CORS preflight that this app never grants. A GET needs no header, as connect_rpc_rails serves GET
# only for RPCs declared free of side effects. Sec-Fetch-Site and Origin, which browsers send, must
# name this origin when present.
#
# @requires_ancestor: ActionController::Metal
module ConnectForgeryProtection
  # Sec-Fetch-Site values of a request this site's own pages made, or the viewer made directly.
  ALLOWED_FETCH_SITES = ['same-origin', 'none'].freeze #: Array[String]

  #: () -> void
  private def verify_connect_request_origin!
    if request.post? && request.headers['Connect-Protocol-Version'] != '1'
      raise ConnectRpcRails::Error.new(:invalid_argument, 'missing required header: set Connect-Protocol-Version to "1"')
    end

    fetch_site = request.headers['Sec-Fetch-Site']
    if fetch_site && !ALLOWED_FETCH_SITES.include?(fetch_site)
      raise ConnectRpcRails::Error.new(:permission_denied, 'cross-site request')
    end

    origin = request.headers['Origin']
    if origin && origin != request.base_url
      raise ConnectRpcRails::Error.new(:permission_denied, 'cross-origin request')
    end
  end
end
