# typed: strict
# frozen_string_literal: true

require 'protobufable/alba_binding'

module SponsorsFile
  # Base of the resources that build the sponsors file, each bound to its message in sponsors_file.proto.
  class ApplicationResource
    include Alba::Resource
    include Protobufable::AlbaBinding

    # Sponsorships under one key of a mapping. Alba would serialize a bare Array as a collection.
    Group = Data.define(:sponsors)

    # Lowercase, each character other than a-z and 0-9 replaced by "_", as the file keys its mappings.
    #: (String) -> String
    def self.key_of(name) = name.downcase.gsub(/[^a-z0-9]/, '_')

    #: (Sponsorship) -> String
    def self.base_plan_of(sponsorship)
      Must.because(sponsorship.plan) { "the sponsors file lists sponsorships with presence, which have a plan" }.name.downcase
    end

    # The file names each field with a Symbol, where Alba writes a String, and lists the fields in the
    # message's declaration order, whatever order the resource declares its attributes in. A collection
    # is an Array of these Hashes.
    #: () -> untyped
    def serializable_hash
      serialized = super
      serialized.is_a?(Array) ? serialized.map { in_field_order(it) } : in_field_order(serialized)
    end

    #: (Hash[String, untyped]) -> Hash[Symbol, untyped]
    private def in_field_order(serialized)
      self.class.message_class.descriptor.to_h { |field| [field.name.to_sym, serialized.fetch(field.name)] }
    end

    #: () -> untyped
    def to_h = serializable_hash
  end
end
