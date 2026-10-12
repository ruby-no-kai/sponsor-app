# typed: true

# Readers of the including models, which Sorbet cannot see from the module.
module EditingHistoryTarget
  sig do
    returns(
      T.any(
        SponsorshipEditingHistory::PrivateCollectionProxy,
        SponsorEventEditingHistory::PrivateCollectionProxy,
        ExhibitionEditingHistory::PrivateCollectionProxy,
      ),
    )
  end
  def editing_histories; end

  sig { returns(T::Hash[String, T.untyped]) }
  def to_h_for_history; end
end
