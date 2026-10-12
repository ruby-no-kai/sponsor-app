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

class Conference::GithubRepo
  sig { returns(String) }
  def raw; end

  sig { returns(String) }
  def name; end

  sig { returns(String) }
  def path; end

  sig { returns(T.nilable(String)) }
  def branch; end
end

# Members hold admin-supplied JSON, which #valid? checks.
class FormDescription::FallbackOptionCondition
  sig { returns(T.untyped) }
  def plans; end

  sig { returns(T.untyped) }
  def booth_request; end
end

# Members other than conditions hold admin-supplied JSON, which #valid? checks.
class FormDescription::FallbackOption
  sig { returns(T.untyped) }
  def value; end

  sig { returns(T.untyped) }
  def name; end

  sig { returns(T.nilable(T::Array[FormDescription::FallbackOptionCondition])) }
  def conditions; end

  sig { returns(T.untyped) }
  def priority_human; end
end
