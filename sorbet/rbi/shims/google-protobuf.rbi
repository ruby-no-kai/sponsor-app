# typed: true

# google/protobuf/well_known_types reopens Any with these after tapioca gem has run.
class Google::Protobuf::Any
  sig { params(msg: Google::Protobuf::AbstractMessage, type_url_prefix: String).returns(Google::Protobuf::Any) }
  def self.pack(msg, type_url_prefix = T.unsafe(nil)); end

  sig { params(klass: T.untyped).returns(T.untyped) }
  def unpack(klass); end
end

# google/protobuf/well_known_types reopens Timestamp with this after tapioca gem has run.
class Google::Protobuf::Timestamp
  sig { returns(Time) }
  def to_time; end
end

# The same file reopens Value, converting any JSON value: nil, a number, a string, a boolean, a Hash
# or an Array.
class Google::Protobuf::Value
  sig { params(value: T.untyped).returns(Google::Protobuf::Value) }
  def self.from_ruby(value); end
end
