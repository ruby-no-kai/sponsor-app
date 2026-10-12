# typed: strict
# frozen_string_literal: true

# XXX: move this to somewhere else (is this a model???)

class TitoApi
  #: type json_object = Hash[Symbol, untyped]
  #: type query = Hash[String | Symbol, String | Array[String]]

  ENDPOINT = "https://api.tito.io/v3" #: String
  DEFAULT_TIMEOUT = 20 #: Integer
  CONNECT_TIMEOUT = 3 #: Integer

  #: (?token: String?, ?endpoint: String) -> void
  def initialize(token: Rails.application.config.x.tito.token, endpoint: ENDPOINT)
    @token = token.presence || raise(ArgumentError, "token is blank") #: String
    @endpoint = endpoint
    @http = nil #: HTTPX::Session?
  end

  #: String
  attr_reader :token

  #: String
  attr_reader :endpoint

  #: (String, String) -> json_object
  def get_release(slug, release_slug)
    get("#{slug}/releases/#{escape(release_slug)}")
  end

  #: (String) -> json_object
  def list_releases(slug)
    get("#{slug}/releases")
  end

  #: (String, String | Integer) -> json_object
  def get_discount_code(slug, discount_code_id)
    get("#{slug}/discount_codes/#{escape(discount_code_id.to_s)}")
  end

  #: (String, code: String, type: String, value: String, **untyped) -> json_object
  def create_discount_code(slug, code:, type:, value:, **kwargs)
    post("#{slug}/discount_codes", discount_code: kwargs.merge(code: code, type: type, value: value))
  end

  #: (String, String | Integer, code: String, type: String, value: String, **untyped) -> json_object
  def update_discount_code(slug, id, code:, type:, value:, **kwargs)
    put("#{slug}/discount_codes/#{escape(id.to_s)}", discount_code: kwargs.merge(code: code, type: type, value: value))
  end

  #: (String, ?query) -> json_object
  def list_registrations(slug, query = {})
    get("#{slug}/registrations", query.merge(version: '3.1'))
  end

  #: (String, String | Integer, ?query) -> json_object
  def get_registration(event_slug, registration_slug, query = {})
    # An explicit headers: keeps Sorbet from reading query as keyword arguments.
    get("#{event_slug}/registrations/#{escape(registration_slug.to_s)}", query, headers: nil)
  end

  #: (String, String | Integer) -> json_object
  def cancel_registration(event_slug, registration_slug)
    post("#{event_slug}/registrations/#{escape(registration_slug.to_s)}/cancellation")
  end

  #: (String, String | Integer, content: String) -> json_object
  def create_registration_note(event_slug, registration_slug, content:)
    post("#{event_slug}/registrations/#{escape(registration_slug.to_s)}/notes", note: {content:})
  end

  #: (String, String) -> json_object
  def get_ticket(account_event_slug, ticket_slug)
    get("#{account_event_slug}/tickets/#{escape(ticket_slug)}")
  end

  #: (String, String, **untyped) -> json_object
  def patch_ticket(account_event_slug, ticket_slug, **kwargs)
    patch("#{account_event_slug}/tickets/#{escape(ticket_slug)}", ticket: kwargs)
  end

  #: (String, name: String, code: String, ?description: String, **untyped) -> json_object
  def create_source(slug, name:, code:, description: '', **kwargs)
    post("#{slug}/sources", source: kwargs.merge(name:, code:, description:))
  end

  # Tito expects "Authorization: Token token=<token>".
  #: () -> HTTPX::Session
  def http
    @http ||= HTTPX
      .plugin(:auth)
      .with(
        origin: endpoint_uri.origin,
        base_path: "#{endpoint_uri.path.to_s.chomp("/")}/",
        headers: {'accept' => 'application/json'},
        timeout: {connect_timeout: CONNECT_TIMEOUT, request_timeout: DEFAULT_TIMEOUT},
        debug: Rails.logger,
        debug_level: 2,
        debug_redact: :headers,
      )
      .authorization("token=#{token}", auth_header_type: "Token")
  end

  #: (String, ?query, ?headers: Hash[String, String]?) -> json_object
  def get(path, params = {}, headers: nil)
    request(:get, path, params, nil, headers: headers)
  end

  #: (String, ?params: query, ?body: json_object?, ?headers: Hash[String, String]?, **untyped) -> json_object
  def put(path, params: {}, body: nil, headers: nil, **bodyhash)
    request(:put, path, params, body || bodyhash, headers: headers)
  end

  #: (String, ?params: query, ?body: json_object?, ?headers: Hash[String, String]?, **untyped) -> json_object
  def patch(path, params: {}, body: nil, headers: nil, **bodyhash)
    request(:patch, path, params, body || bodyhash, headers: headers)
  end

  #: (String, ?params: query, ?body: json_object?, ?headers: Hash[String, String]?, ?timeout: Integer, **untyped) -> json_object
  def post(path, params: {}, body: nil, headers: nil, timeout: DEFAULT_TIMEOUT, **bodyhash)
    request(:post, path, params, body || bodyhash, headers: headers, timeout: timeout)
  end

  #: (Symbol, String, ?query, json_object?, ?headers: Hash[String, String]?, ?timeout: Integer) -> json_object
  def request(method, path, params = {}, body, headers: nil, timeout: DEFAULT_TIMEOUT)
    options = {params:} #: Hash[Symbol, untyped]
    options[:json] = body if body
    options[:headers] = headers if headers

    session = http.with(timeout: {connect_timeout: CONNECT_TIMEOUT, request_timeout: timeout})
    response = session.request(method, path, **options)
    response.raise_for_status
    return {} if response.body.empty?

    response.json(symbolize_names: true)
  end

  #: (String) -> String
  def escape(x)
    URI.encode_www_form_component(x)
  end

  #: () -> URI::HTTP
  private def endpoint_uri
    uri = URI(endpoint)
    case uri
    when URI::HTTP then uri
    else raise ArgumentError, "endpoint is not an HTTP(S) URL: #{endpoint}"
    end
  end
end
