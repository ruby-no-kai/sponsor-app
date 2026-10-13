# typed: strict

# Sorbet synthesizes the readers of a `Data.define` class without signatures,
# which a `# typed: strict` file cannot supply inline.

class PassRedemption::Registration
  sig do
    params(
      id: Integer,
      slug: String,
      reference: String,
      discount_code: T.nilable(String),
      source: T.nilable(String),
      email: T.nilable(String),
      state: String,
      free: T::Boolean,
      paid: T::Boolean,
      cancelled: T::Boolean,
      refunded: T::Boolean,
      partially_refunded: T::Boolean,
      tickets: T::Array[PassRedemption::Ticket],
    ).returns(T.attached_class)
  end
  def self.new(id:, slug:, reference:, discount_code:, source:, email:, state:, free:, paid:, cancelled:, refunded:, partially_refunded:, tickets:); end

  sig { returns(Integer) }
  def id; end

  sig { returns(String) }
  def slug; end

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
  sig do
    params(
      id: Integer,
      reference: String,
      discount_code: T.nilable(String),
      release_id: String,
      release_slug: T.nilable(String),
      email: T.nilable(String),
      state: String,
      void: T::Boolean,
      assigned: T::Boolean,
    ).returns(T.attached_class)
  end
  def self.new(id:, reference:, discount_code:, release_id:, release_slug:, email:, state:, void:, assigned:); end

  sig { returns(Integer) }
  def id; end

  sig { returns(String) }
  def reference; end

  sig { returns(T.nilable(String)) }
  def discount_code; end

  sig { returns(String) }
  def release_id; end

  sig { returns(T.nilable(String)) }
  def release_slug; end

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

class CreateBroadcastDeliveriesJob::Recipient
  sig { returns(T.nilable(Sponsorship)) }
  def sponsorship; end

  sig { returns(String) }
  def email; end

  sig { returns(T::Array[String]) }
  def email_ccs; end
end

class TitoTicketRetraction::Preconditions
  sig do
    params(
      free: T::Boolean,
      paid: T::Boolean,
      refunded: T::Boolean,
      partially_refunded: T::Boolean,
      cancelled: T::Boolean,
      ticket_release_count: Integer,
      ticket_discount_code_count: Integer,
      discount_codes_used: T::Array[T.nilable(String)],
      invalid_discount_codes: T::Array[T.nilable(String)],
      valid_discount_code_used: T::Boolean,
    ).returns(T.attached_class)
  end
  def self.new(free:, paid:, refunded:, partially_refunded:, cancelled:, ticket_release_count:, ticket_discount_code_count:, discount_codes_used:, invalid_discount_codes:, valid_discount_code_used:); end

  sig { returns(T::Boolean) }
  def free; end

  sig { returns(T::Boolean) }
  def paid; end

  sig { returns(T::Boolean) }
  def refunded; end

  sig { returns(T::Boolean) }
  def partially_refunded; end

  sig { returns(T::Boolean) }
  def cancelled; end

  sig { returns(Integer) }
  def ticket_release_count; end

  sig { returns(Integer) }
  def ticket_discount_code_count; end

  sig { returns(T::Array[T.nilable(String)]) }
  def discount_codes_used; end

  sig { returns(T::Array[T.nilable(String)]) }
  def invalid_discount_codes; end

  sig { returns(T::Boolean) }
  def valid_discount_code_used; end
end

class EnsureSponsorshipTitoDiscountCodeJob::DiscountCodeAttributes
  sig do
    params(
      code: String,
      type: String,
      value: String,
      only_show_attached: T::Boolean,
      reveal_secret: T::Boolean,
      block_registrations_if_not_applicable: T::Boolean,
      quantity: Integer,
      release_ids: T.nilable(T::Array[String]),
      source_id: String,
      description_for_organizer: String,
    ).returns(T.attached_class)
  end
  def self.new(code:, type:, value:, only_show_attached:, reveal_secret:, block_registrations_if_not_applicable:, quantity:, release_ids:, source_id:, description_for_organizer:); end

  sig { returns(String) }
  def code; end

  sig { returns(String) }
  def type; end

  sig { returns(String) }
  def value; end

  sig { returns(T::Boolean) }
  def only_show_attached; end

  sig { returns(T::Boolean) }
  def reveal_secret; end

  sig { returns(T::Boolean) }
  def block_registrations_if_not_applicable; end

  sig { returns(Integer) }
  def quantity; end

  sig { returns(T.nilable(T::Array[String])) }
  def release_ids; end

  sig { returns(String) }
  def source_id; end

  sig { returns(String) }
  def description_for_organizer; end
end

class SponsorsFile::ApplicationResource::Group
  sig { params(sponsors: T::Array[Sponsorship]).returns(T.attached_class) }
  def self.new(sponsors:); end

  sig { returns(T::Array[Sponsorship]) }
  def sponsors; end
end
