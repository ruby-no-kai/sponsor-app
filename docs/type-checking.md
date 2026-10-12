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
| `third_party/sorbet/rbi/gems/` | gem RBIs from `tapioca gem` | yes |
| `third_party/sorbet/rbi/dsl/` | Rails DSL RBIs (models, associations, routes) from `tapioca dsl` | yes |
| `app/models/must.rb` | `Must`, the runtime counterpart of `T.must` | no |

## Commands

| Command | What it does |
|---------|--------------|
| `mise run typecheck` | `bundle exec srb tc` |
| `hk check` | every linter, Sorbet included; also the pre-commit hook |
| `mise run tapioca` | regenerates gem, annotation and DSL RBIs |
| `bundle exec tapioca gem` | gem RBIs, after `Gemfile.lock` changes |
| `bundle exec tapioca dsl` | DSL RBIs, after adding a model, column, association or route |
| `bundle exec tapioca annotations` | community annotations |
| `bin/check-strict-sigils BASE` | fails when a Ruby file added since `BASE` is below `strict` |

Run `bundle` under the mise environment (`mise x -- bundle ...`, or a shell with mise activated). `sorbet-static` ships only platform gems, so `Gemfile.lock` has no `ruby` platform and `BUNDLE_FORCE_RUBY_PLATFORM` must be false.

`tapioca dsl` boots Rails against the development database. Bring it up with `docker compose up -d db` first.

Nothing detects stale RBIs. Regenerate them in the same change that moves `Gemfile.lock` or the schema.

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

- `Data.define` readers have no inline form. Declare them in `sorbet/rbi/shims/data_define.rbi`.
- `belongs_to` readers are nilable in the DSL RBIs, even when the association is required. Read them with `Must.expect`.
- `NOT NULL` columns are typed non-nil, although an unsaved record can still hold nil.
- Methods and `include`s inside an `included do` block are invisible to Sorbet. Include the module directly, or declare the method in a shim.
- `include` of a module built at runtime, such as `Rails.application.routes.url_helpers`, is error 4002 at every level. `ApplicationJob` includes it inside `class_eval`; tapioca's url helpers compiler declares the helpers.
- Files evaluated in another tool's DSL and unable to resolve, such as `config/ci.rb`, are `typed: ignore`.
- A spec whose anonymous class defines `initialize` or `self.name` leaks those definitions into `Object` for the whole project. Such a spec is `typed: ignore`.

## References

- <https://sorbet.org/docs/rbs-support>
- <https://sorbet.org/docs/gradual>
- <https://github.com/Shopify/spoom>
- CI: the `typecheck` job in `.github/workflows/_test.yml`
- Pre-commit: the `sorbet` step in `hk.pkl`
