# typed: strict

# Sorbet synthesizes the readers of a `Data.define` class without signatures,
# which a `# typed: strict` file cannot supply inline.

class PassRedemption::Registration
  sig { returns(Integer) }
  def id; end

  sig { returns(String) }
  def reference; end

  sig { returns(T.nilable(String)) }
  def discount_code; end

  sig { returns(T.nilable(String)) }
  def source; end

  sig { returns(T.nilable(String)) }
  def email; end

  sig { returns(String) }
  def state; end

  sig { returns(T::Boolean) }
  def free; end

  sig { returns(T::Boolean) }
  def paid; end

  sig { returns(T::Boolean) }
  def cancelled; end

  sig { returns(T::Boolean) }
  def refunded; end

  sig { returns(T::Boolean) }
  def partially_refunded; end

  sig { returns(T::Array[PassRedemption::Ticket]) }
  def tickets; end
end

class PassRedemption::Ticket
  sig { returns(Integer) }
  def id; end

  sig { returns(String) }
  def reference; end

  sig { returns(T.nilable(String)) }
  def discount_code; end

  sig { returns(T.nilable(TitoCachedRelease)) }
  def release; end

  sig { returns(String) }
  def release_id; end

  sig { returns(T.nilable(String)) }
  def email; end

  sig { returns(String) }
  def state; end

  sig { returns(T::Boolean) }
  def void; end

  sig { returns(T::Boolean) }
  def assigned; end
end
