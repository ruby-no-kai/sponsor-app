# frozen_string_literal: true

require 'base64'
require 'json'
require 'uri'

# Calls Connect RPCs from request specs the way a Connect client does.
module ConnectHelper
  PACKAGE = 'rubykaigi.sponsor_app'

  CONTENT_TYPES = {json: 'application/json', proto: 'application/proto'}.freeze

  # One RPC of a service: where it is served and which messages it takes and returns.
  MethodDesc = Data.define(:service_name, :descriptor) do
    delegate :name, to: :descriptor

    def path = "/#{service_name}/#{name}"
    def input_class = descriptor.input_type.msgclass
    def output_class = descriptor.output_type.msgclass
  end

  # A Connect error response, with each detail decoded into its message.
  ConnectError = Data.define(:status, :code, :message, :details) do
    def detail(klass) = details.find { it.is_a?(klass) }
  end

  # `connect_method('AdminService', 'GetViewer')`
  def connect_method(service, name)
    service_name = "#{PACKAGE}.#{service}"
    service_desc = Google::Protobuf::DescriptorPool.generated_pool.lookup(service_name) or raise "no service #{service_name}"
    descriptor = service_desc.find { it.name == name } or raise "#{service_name} has no RPC #{name}"

    MethodDesc.new(service_name:, descriptor:)
  end

  # Returns the decoded response message, or a ConnectError for any other answer.
  def connect_call(method_desc, request, via: :post, codec: :json, headers: {})
    case via
    when :post
      body = codec == :json ? request.class.encode_json(request) : request.class.encode(request)
      post method_desc.path, params: body, headers: {
        'Content-Type' => CONTENT_TYPES.fetch(codec),
        'Connect-Protocol-Version' => '1',
        **headers,
      }
    when :get
      query = {connect: 'v1', encoding: codec.to_s}
      if codec == :json
        query[:message] = request.class.encode_json(request)
      else
        query[:base64] = '1'
        query[:message] = Base64.urlsafe_encode64(request.class.encode(request), padding: false)
      end
      get "#{method_desc.path}?#{URI.encode_www_form(query)}", headers:
    else
      raise ArgumentError, "unknown verb #{via.inspect}"
    end

    connect_response(method_desc, codec)
  end

  def connect_response(method_desc, codec)
    if response.status == 200
      return codec == :json ? method_desc.output_class.decode_json(response.body) : method_desc.output_class.decode(response.body)
    end
    unless response.media_type == 'application/json'
      return ConnectError.new(status: response.status, code: nil, message: response.body, details: [])
    end

    body = JSON.parse(response.body)
    details = body.fetch('details', []).map do |detail|
      klass = Google::Protobuf::DescriptorPool.generated_pool.lookup(detail.fetch('type')).msgclass
      klass.decode(Base64.decode64(detail.fetch('value')))
    end
    ConnectError.new(status: response.status, code: body.fetch('code'), message: body['message'], details:)
  end

  def sign_in_staff(staff)
    get claim_user_session_path(FactoryBot.create(:session_token, staff:).handle)
  end

  # Signs in as the primary contact of every sponsorship listing the email.
  def sign_in_sponsor(email)
    get claim_user_session_path(FactoryBot.create(:session_token, email:).handle)
  end
end

RSpec.configure do |config|
  config.include ConnectHelper, type: :request
end
