# typed: strict
# frozen_string_literal: true

# Passes a protobuf message as an ActiveJob argument, stored as its full name and ProtoJSON in .proto field names.
class ProtobufMessageSerializer < ActiveJob::Serializers::ObjectSerializer
  #: (Google::Protobuf::AbstractMessage) -> Hash[String, untyped]
  def serialize(message)
    message_class = message.class
    super(
      'message' => message_class.descriptor.name,
      'json' => message_class.encode_json(message, preserve_proto_fieldnames: true),
    )
  end

  # Drops unknown fields, so a release reads what a newer release enqueued.
  #: (Hash[String, untyped]) -> Google::Protobuf::AbstractMessage
  def deserialize(hash)
    name = hash.fetch('message')
    descriptor = Google::Protobuf::DescriptorPool.generated_pool.lookup(name)
    raise ArgumentError, "unknown protobuf message: #{name}" unless descriptor

    descriptor.msgclass.decode_json(hash.fetch('json'), ignore_unknown_fields: true)
  end

  # Google::Protobuf::AbstractMessage, the superclass of generated messages, is a private constant.
  #: () -> Module[untyped]
  def klass = Google::Protobuf::MessageExts
end
