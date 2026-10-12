# typed: true

# Columns of the including models, which Sorbet cannot see from the module.
module MarkdownBody
  sig { returns(String) }
  def body; end

  sig { returns(ActiveSupport::TimeWithZone) }
  def updated_at; end
end
