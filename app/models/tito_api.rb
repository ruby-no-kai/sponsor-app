# XXX: move this to somewhere else (is this a model???)

class TitoApi
  ENDPOINT = "https://api.tito.io/v3"

  def initialize(token: Rails.application.config.x.tito.token, endpoint: ENDPOINT)
    @token = token
    @endpoint = ENDPOINT
    raise ArgumentError, "token is blank" if @token.blank?
  end

  attr_reader :token, :endpoint

  def get_release(slug, release_slug)
    get("#{slug}/releases/#{escape(release_slug)}").body
  end

  def list_releases(slug)
    get("#{slug}/releases").body
  end

  def get_discount_code(slug, discount_code_id)
    get("#{slug}/discount_codes/#{escape(discount_code_id.to_s)}").body
  end

  def create_discount_code(slug, code:, type:, value:, **kwargs)
    post("#{slug}/discount_codes", discount_code: kwargs.merge(code: code, type: type, value: value)).body
  end

  def update_discount_code(slug, id, code:, type:, value:, **kwargs)
    put("#{slug}/discount_codes/#{escape(id.to_s)}", discount_code: kwargs.merge(code: code, type: type, value: value)).body
  end

  def get_ticket(account_event_slug, ticket_slug)
    get("#{account_event_slug}/tickets/#{escape(ticket_slug)}").body
  end

  def patch_ticket(account_event_slug, ticket_slug, **kwargs)
    patch("#{account_event_slug}/tickets/#{escape(ticket_slug)}", ticket: kwargs).body
  end

  def create_source(slug, name:, code:, description: '', **kwargs)
    post("#{slug}/sources", source: kwargs.merge(name:, code:, description:)).body
  end

  def default_headers
    {
      'Authorization' => "Token token=#{token}",
    }
  end

  def faraday
    @faraday ||= Faraday.new(headers: default_headers, url: endpoint) do |builder|
      builder.use Faraday::Response::Logger, Rails.logger, bodies: true do |log|
        log.filter(/^authorization:.+$/i, 'authorization: [redacted]')
      end if true
      builder.use FaradayMiddleware::ParseJson, :content_type => /\bjson$/, :parser_options => { :symbolize_names => true }
      builder.use FaradayMiddleware::EncodeJson
      builder.use Faraday::Response::RaiseError

      builder.adapter :net_http
    end
  end

  def get(path, params = {}, headers: nil)
    request(:get, path, params, nil, headers: headers)
  end

  def put(path, params: {}, body: nil, headers: nil, **bodyhash)
    request(:put, path, params, body || bodyhash, headers: headers)
  end

  def patch(path, params: {}, body: nil, headers: nil, **bodyhash)
    request(:patch, path, params, body || bodyhash, headers: headers)
  end

  def post(path, params: {}, body: nil, headers: nil, timeout: 20, **bodyhash)
    request(:post, path, params, body || bodyhash, headers: headers, timeout: timeout)
  end

  def request(method, path, params = {}, body, conn: faraday, headers: nil, timeout: 20)
    conn.send(method) do |req|
      req.url(path, params)
      if body
        req.body = body 
        req.headers['Accept'] = 'application/json'
        req.headers['Content-Type'] = 'application/json'
      end
      req.headers.update(headers) if headers
      req.options.timeout = timeout
      req.options.open_timeout = 3
    end
  end

  def escape(x)
    URI.encode_www_form_component(x)
  end
end
