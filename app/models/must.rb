# typed: strict
# frozen_string_literal: true

# Runtime counterpart of Sorbet's T.must for a value the type checker cannot
# prove present. The reason names the invariant that makes it so.
module Must
  class Violation < StandardError; end

  #: [T] (T? value) { () -> String } -> T
  def self.because(value, &_block)
    case value
    when nil then raise Violation, yield
    else value
    end
  end

  #: [T] (T? value) -> T
  def self.expect(value)
    case value
    when nil then raise Violation, "expected a value, got nil"
    else value
    end
  end

  #: [T] (untyped value, Class[T] klass) -> T
  def self.be_a(value, klass)
    case value
    when klass then value
    else raise Violation, "expected #{klass}, got #{value.class}"
    end
  end
end
