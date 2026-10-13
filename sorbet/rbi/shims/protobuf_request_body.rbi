# typed: true

# ActiveSupport::Concern extends the including class with the ClassMethods of RequestParseable and
# RequestValidatable, which Sorbet does not carry through a module that includes them.
module ProtobufRequestBody
  mixes_in_class_methods Protobufable::RequestParseable::ClassMethods
  mixes_in_class_methods Protobufable::RequestValidatable::ClassMethods
end
