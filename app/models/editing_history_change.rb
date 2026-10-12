# typed: strict
# frozen_string_literal: true

# One row of an editing history's diff, as Hashdiff writes it: [op, path, value] for an addition or a
# removal, and [op, path, old, new] for a change. Values are JSON, as the diff column stores them.
class EditingHistoryChange
  #: (Array[untyped]) -> void
  def initialize(row)
    @row = row #: Array[untyped]
  end

  # "+" for an addition, "-" for a removal, "~" for a change.
  #: () -> String
  def operation = @row.fetch(0)

  # Where the value sits in the snapshot, such as "contact.email" or "tags[2]".
  #: () -> String
  def path = @row.fetch(1).to_s

  # Whether the path held a value before the save, which it did not for an addition.
  #: () -> bool
  def old_value? = operation != '+'

  # Whether the path holds a value after the save, which it does not after a removal.
  #: () -> bool
  def new_value? = operation != '-'

  #: () -> untyped
  def old_value
    raise ArgumentError, "an addition to #{path} has no old value" unless old_value?

    @row.fetch(2)
  end

  #: () -> untyped
  def new_value
    raise ArgumentError, "a removal of #{path} has no new value" unless new_value?

    @row.fetch(operation == '~' ? 3 : 2)
  end
end
