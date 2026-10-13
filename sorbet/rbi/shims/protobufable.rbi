# typed: true

# AlbaBinding.included installs HelperMethods through Alba's `helper`, which tapioca cannot see.
module Protobufable::AlbaBinding
  mixes_in_class_methods Protobufable::AlbaBinding::HelperMethods
end
