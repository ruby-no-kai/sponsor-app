# typed: true

# Columns and readers of the including models, which Sorbet cannot see from
# the module.
module EditingHistory
  sig { returns(T.nilable(T::Array[T::Array[T.untyped]])) }
  def diff; end

  sig { params(value: T.nilable(T::Array[T::Array[T.untyped]])).returns(T.nilable(T::Array[T::Array[T.untyped]])) }
  def diff=(value); end

  sig { returns(T::Hash[String, T.untyped]) }
  def raw; end

  sig { returns(T.nilable(T.any(Sponsorship, SponsorEvent, Exhibition))) }
  def target; end
end
