# Type checking

The app typechecks with [Sorbet](https://sorbet.org/) using inline RBS comments (`#:`). Types are static only: `sorbet-runtime` is never required by the app, so nothing about the types runs in production.

## Layout

| Path | Contents | Generated |
|------|----------|-----------|
| `sorbet/config` | `srb tc` options | no |
| `sorbet/tapioca/config.yml` | tapioca output directories, excluded gems, annotation overrides | no |
| `sorbet/tapioca/require.rb` | entrypoints tapioca loads beyond `Bundler.require` | no |
| `sorbet/rbi/annotations/` | community annotations from `tapioca annotations` | yes |
| `sorbet/rbi/shims/` | hand-written RBIs for what tapioca cannot see | no |
| `sorbet/rbi/shims/<concern>.rbi` | columns and readers a concern reads from its including classes | no |
| `third_party/sorbet/rbi/gems/` | gem RBIs from `tapioca gem` | yes |
| `third_party/sorbet/rbi/dsl/` | Rails and protobuf DSL RBIs (models, associations, routes, messages) from `tapioca dsl` | yes |
| `app/models/must.rb` | `Must`, the runtime counterpart of `T.must` | no |

## Commands

| Command | What it does |
|---------|--------------|
| `mise run typecheck` | `bundle exec srb tc` |
| `hk check` | every linter, Sorbet included; also the pre-commit hook |
| `mise run tapioca` | regenerates gem, annotation and DSL RBIs, skipping the gems excluded in `sorbet/tapioca/config.yml` |
| `bundle exec tapioca gem` | gem RBIs, after `Gemfile.lock` changes |
| `bundle exec tapioca dsl` | DSL RBIs, after adding a model, column, association, route or `protobuf_body` declaration |
| `mise run gen` | `gen/` and the protobuf message RBIs from tapioca's Protobuf compiler, after a `.proto` change |
| `bundle exec tapioca annotations` | community annotations |
| `bin/check-strict-sigils BASE` | fails when a Ruby file added since `BASE` is below `strict` |

Run `bundle` under the mise environment (`mise x -- bundle ...`, or a shell with mise activated). `sorbet-static` ships only platform gems, so `Gemfile.lock` has no `ruby` platform and `BUNDLE_FORCE_RUBY_PLATFORM` must be false.

`tapioca dsl` boots Rails against the development database. Bring it up with `docker compose up -d db` first. `mise run gen` needs no database.

Regenerate RBIs in the same change that moves `Gemfile.lock`, the database schema or a `.proto` file. CI detects stale protobuf message RBIs only.

## Writing types

Signatures are `#:` comments, continued with `#|`:

```ruby
#: (String, expires_in: Integer, ?scopes: Array[String]) -> Token
def issue(subject, expires_in:, scopes: [])

#: (Sponsorship, staff: Staff?,
#|  ?notify: bool) -> void
def record(sponsorship, staff:, notify: true)

DEFAULT_TTL = 300 #: Integer

def initialize(sponsorship:)
  @sponsorship = sponsorship #: Sponsorship
  @history = nil #: SponsorshipEditingHistory?
end
```

- Give every method, constant and instance variable a type. Declare instance variables in `initialize`, nilable when a later step fills them.
- Never write `sig` blocks, `extend T::Sig`, `T.let`, `T.must` or `T.cast` in a `.rb` file. They need `sorbet-runtime`. `.rbi` shims use `sig` blocks.
- Never run `srb tc -a`; its autocorrect writes those forms.

### Nilable values

Never cast with `#: as !nil`. In order of preference:

1. Restructure so the nil never exists: `fetch`, an `else raise` arm, returning the value of a block.
2. Bind the value to a local and guard the local. Sorbet narrows locals, not method calls.
3. Give the owner a reader that raises, with a `_maybe` sibling for callers that accept nil.
4. `Must.because(value) { "invariant that makes it present" }`.
5. `Must.expect(value)` for a non-optional `belongs_to` reader, which tapioca types nilable.

### Union values

- Narrow with `Must.be_a(value, Klass)`, never `#: as Klass`.
- End a `case` over every member with `else value #: absurd`.
- `untyped` is for values that really are heterogeneous, such as parsed JSON. It never silences an error.

## Strictness

| Sigil | Reports |
|-------|---------|
| `# typed: ignore` | nothing; the file is not read |
| `# typed: false` | syntax and constant resolution errors |
| `# typed: true` | type errors in method bodies; signatures optional |
| `# typed: strict` | also a missing signature on any method, constant or instance variable |

New Ruby files under `app/`, `lib/` and `config/` start at `# typed: strict`, which CI enforces. Spec files carry no sigil.

To raise an older file, `bundle exec spoom srb bump --from false --to true` finds files that pass at the next level. Never run `spoom bump --help`: that deprecated command ignores `--help` and bumps files.

## Known gaps

- `Struct` members have untyped readers, so value objects use `Data.define`. Its readers have no inline form. Declare them in `sorbet/rbi/shims/data_define.rbi`.
- Sorbet checks only the argument count of a `Data.define` constructor. Its shim block also declares `def self.new(id:, ...)` with `sig { params(id: Integer, ...).returns(T.attached_class) }`, which makes Sorbet check the keys and value types. A sig on `initialize` is rejected (4010) instead. `Data#with` stays unchecked.
- `belongs_to` readers are nilable in the DSL RBIs, even when the association is required. Read them with `Must.expect`.
- `NOT NULL` columns are typed non-nil, although an unsaved record can still hold nil.
- `Rails.application.config.x` and a parameterized mailer's `params` return untyped. Declare the value where it is read when a type is needed: `delivery = params[:delivery] #: BroadcastDelivery`.
- `delegate` defines untyped methods and `Method#call` returns untyped. Write a typed one-line reader instead of `delegate`, and pass a lambda typed `^(A) -> R` instead of `method(:name)`.
- `perform_later` and `perform_now` take untyped arguments, as tapioca's ActiveJob compiler reads parameter types only from runtime `sig`s. A wrong argument type is not reported.
- Methods and `include`s inside an `included do` block are invisible to Sorbet. Include the module directly, or declare the method in a shim.
- A concern that calls its host's methods names the host above `module` with `# @requires_ancestor: ActiveRecord::Base` (or `ApplicationController`). Columns and readers that only the including classes define go in `sorbet/rbi/shims/<concern>.rbi`.
- Inside a concern, `self.class` reaches `ClassMethods` only through a cast: `self.class #: as singleton(ActiveRecord::Base) & ClassMethods`.
- A concern cannot declare an instance variable that only its including classes assign, as inline RBS declares one only at an assignment. Declare a reader that each including class implements instead.
- `include` of a module built at runtime, such as `Rails.application.routes.url_helpers`, is error 4002 at every level. `ApplicationJob` includes it inside `class_eval`; tapioca's url helpers compiler declares the helpers.
- A block or file that a DSL evaluates with another `self`, such as `ActiveSupport.on_load`, `OmniAuth::Builder`, a mailer's `default subject: -> { }` or `config/puma.rb`, starts with `#: self as <Host>`.
- Sorbet types the `self` of a bare lambda in a class body as the class, so a validation or callback condition takes the record: `if: ->(record) { record.persisted? }`.
- Sorbet reads a Hash passed to an optional positional parameter as keyword arguments when the callee also takes keywords. Pass one of the keywords explicitly, as `TitoApi#get_registration` does.
- A splat of an array whose size is not known statically is error 7019 at every level above `false`. `config/lambda_runner.rb` stays at `false` for this.
- A `Hash` keyword splat into a method with required keywords is error 7019, and `Data#to_h` returns an untyped `Hash`. Spell the keywords out, as `EnsureSponsorshipTitoDiscountCodeJob` does for `TitoApi`.
- Tapioca emits no instance variables. One that a gem assigns and a patch reads is declared with `T.let` in an `initialize` body in the gem's shim, as in `sorbet/rbi/shims/aws-sdk-s3.rbi`.
- Files evaluated in another tool's DSL and unable to resolve, such as `config/ci.rb`, are `typed: ignore`.
- A spec whose anonymous class defines `initialize` or `self.name` leaks those definitions into `Object` for the whole project. Such a spec is `typed: ignore`.
- Sorbet does not read the `.rbs` that protoc writes into `gen/`. Tapioca's Protobuf DSL compiler types the generated messages instead.
- Tapioca types an attribute declared with `Protobufable::JsonType` untyped, as the type has no signature it can read. Declare the reader in `sorbet/rbi/shims/<model>.rbi`, as `sorbet/rbi/shims/expense_report_submission.rbi` does.
- `message`, the request body an action declares with `protobuf_body`, is typed by protobufable's tapioca DSL compiler as the declared class, or the union of the classes a controller's actions declare.
- Sorbet extends a class with a concern's `ClassMethods` only when the class includes that concern itself, not through another module. A concern including one declares `mixes_in_class_methods` in a shim, as `sorbet/rbi/shims/protobuf_request_body.rbi` does.
- `connect_request` in a Connect controller returns untyped. Read a field into a local declared with its type: `slug = connect_request.conference_slug #: String`.
- `tapioca gem` sees only what a gem's entrypoint loads, so optional integrations such as `protobufable/connect` are listed in `sorbet/tapioca/require.rb`.

## References

- <https://sorbet.org/docs/rbs-support>
- <https://sorbet.org/docs/gradual>
- <https://github.com/Shopify/spoom>
- CI: the `typecheck` job in `.github/workflows/_test.yml`
- Pre-commit: the `sorbet` step in `hk.pkl`
