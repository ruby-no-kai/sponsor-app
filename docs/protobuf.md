# Protobuf-first design

Protocol Buffers are the schema of record for this app's API and for structured data at rest. A `.proto` file defines what a request carries, what a response returns, which errors exist, and what a `jsonb` column holds. Ruby and TypeScript are generated from it, so a payload crossing a boundary is a generated message and not a Hash literal. The SPA speaks JSON; the Connect endpoints also accept binary protobuf.

This page explains how the pieces fit. [CLAUDE.md](../CLAUDE.md) holds the operational rules: the commands, how to add an RPC, how to add a message column.

| Concern | Where it lives |
|---------|----------------|
| Schema | `proto/rubykaigi/sponsor_app/*.proto` |
| Generated Ruby and RBS | `gen/proto/ruby/` (`sponsor_app-proto` path gem) |
| Generated TypeScript | `ui/src/gen/` (the SPA), `app/javascript/gen/` (HAML-side scripts) |
| RPC controllers | `app/controllers/api/{admin,sponsor}/` |
| Response builders | `app/resources/api/` |
| Problem types | `proto/.../problem.proto`, `app/models/errors.rb` |
| Message columns | `proto/.../internal/`, `Protobufable::JsonType` |
| SPA client | `ui/src/lib/{rpc,errors,rejection}.ts` |

## 1. `proto/` and the toolchain

`proto/` is a [buf](https://buf.build/) module (`buf.yaml`) in the package `rubykaigi.sponsor_app`. Every file sets `option ruby_package = "Rk::SponsorApp"`. Files are grouped by who reads them:

- `admin_*.proto` and `sponsor_*.proto` hold the requests and responses of `AdminService` and `SponsorService`, next to the two service definitions (`admin_service.proto`, `sponsor_service.proto`).
- Unprefixed files (`conference.proto`, `expense_report.proto`) hold the resources both services publish.
- `problem.proto` is the error catalogue.
- `internal/` holds storage messages and job arguments that no RPC may reach.
- `protobufable/` is copied from the protobufable gem for buf and never edited.

Three templates generate code, because their inputs differ:

| Template | Output | Notes |
|----------|--------|-------|
| `buf.gen.yaml` | `gen/proto/ruby/lib/**/*_pb.rb`, `gen/proto/ruby/sig/**/*_pb.rbs` | The `protoc` builtins `ruby` and `rbs`. `proto/protobufable` is excluded, as the gem ships its own Ruby and a second copy of a descriptor raises. |
| `buf.gen.es.yaml` | `ui/src/gen/**/*_pb.ts` | protoc-gen-es from `ui/node_modules`, plus `google/rpc/error_details.proto`. `internal/` is excluded. |
| `buf.gen.javascript.yaml` | `app/javascript/gen/**/*_pb.ts` | protoc-gen-es from the root `node_modules`, for the HAML pages' scripts. Only the messages listed under `types` are generated (section 8). |

`gen/proto/ruby/` is a path gem the `Gemfile` loads at boot. The generator writes only `*_pb.rb` and `*_pb.rbs`; the gemspec and `lib/sponsor_app-proto.rb` beside them are hand-written, so `clean: true` stays off.

One command runs everything whose output is committed:

```bash
mise run gen    # buf build, buf generate (Ruby/RBS), buf generate (TypeScript), then tapioca's message RBIs
```

`gen:proto` runs `buf build` first, so a `.proto` that does not compile leaves `gen/` untouched. Sorbet cannot read the generated `.rbs`, so `gen:rbi` runs `tapioca dsl --only=Protobuf` to produce the RBIs it uses (see [type-checking.md](type-checking.md)).

Generated files are committed, and CI keeps them honest. The `gen` job in `.github/workflows/_test.yml` runs `mise run --force gen` and fails when `git status --porcelain` is not empty, which also catches generated files that were never added. hk's pre-commit hook regenerates and stages them.

Proto doc comments are user-facing: they become JSDoc in `ui/src/gen`, and they are what a reviewer reads. A comment-only edit leaves only the TypeScript stale, so regenerate after every `.proto` edit.

### Dev loop

The `Procfile` closes the loop:

```
web:   mise watch -w gen/proto/ruby -w Gemfile.lock -o restart --debounce 2s --no-vcs-ignore server
proto: mise watch gen:proto
```

Editing a `.proto` makes `proto` regenerate, which restarts Rails and hot-reloads the SPA. Rails restarts because message classes cannot be reloaded: google-protobuf raises when a descriptor is registered twice, so Zeitwerk cannot re-require a `_pb.rb`. Generated classes load once through Bundler, which also means they exist in initializers.

## 2. Connect RPC on ActionController

The services are served over the [Connect protocol](https://connectrpc.com/docs/protocol/) by [connect_rpc_rails](https://github.com/ivry-inc/connect_rpc_rails). It is plain ActionController, so Puma, cookies, `rescue_from`, Sentry and request specs all work as in the rest of the app, and there is no separate gRPC server. Unary calls only.

Routes name the controller for each RPC (`config/routes.rb`):

```ruby
connect_service 'rubykaigi.sponsor_app.AdminService' do
  # Conferences
  rpc 'ListConferences' => 'api/admin/conferences'
  rpc 'GetConference' => 'api/admin/conferences'
```

A controller defines one action per RPC, in snake case, and returns the response message:

```ruby
authorize :conference
#: () -> Rk::SponsorApp::AdminServiceGetPlanResponse
def get_plan
  Rk::SponsorApp::AdminServiceGetPlanResponse.new(plan: admin_plan_message(find_plan))
end
```

The same endpoint answers in several encodings, which `curl` and the SPA both use:

- POST with a JSON body (`Content-Type: application/json`) or a binary message (`application/proto`). A POST must send `Connect-Protocol-Version: 1`.
- GET with `?connect=v1&encoding=json&message=<urlencoded JSON>`, only for RPCs marked `option idempotency_level = NO_SIDE_EFFECTS;`. A GET of any other RPC is refused with 405. The SPA sets `useHttpGet: true` and the generated method options decide.

`CLAUDE.md` ("Connect RPC API") has the curl recipes.

### Authorization

Every RPC declares a policy on the line above its `def`. `Api::ApplicationController` collects it with `method_added`, and a controller serving an RPC with no policy raises `UndeclaredPolicy` the first time it is called. Each service's base controller names the policies it offers and enforces them:

| Service | Policies | Enforced in |
|---------|----------|-------------|
| `AdminService` | `:any_staff`, `:unrestricted_staff`, `:conference` | `Api::Admin::ApplicationController` |
| `SponsorService` | `:sponsorship`, `:public` | `Api::Sponsor::ApplicationController` |

Order matters: authentication runs first, then the request message is validated, then the policy. A policy that looks a resource up (`:conference` reads `conference_slug`, which must be field 1) therefore sees only valid requests. `spec/proto/services_spec.rb` walks every RPC of both services and fails when one is not routed to an action with a policy, or reaches an `internal` type.

Browsers are protected without a CSRF token: `ConnectForgeryProtection` refuses a POST that lacks `Connect-Protocol-Version` and any request whose `Sec-Fetch-Site` or `Origin` names another origin. The app never grants a CORS preflight.

## 3. Request validation with protovalidate

Rules are written on the field in the `.proto` with [protovalidate](https://github.com/bufbuild/protovalidate) (`buf.validate`, pinned in `buf.yaml`):

```proto
string slug = 2 [
  (buf.validate.field).required = true,
  (buf.validate.field).string = {
    max_len: 64
    pattern: "^[a-z0-9][a-z0-9_-]*$"
  }
];
```

Standard rules cover most fields. When the message a person reads matters, a CEL rule carries its own text and a stable `id`:

```proto
(buf.validate.field).cel = {
  id: "conference.name.not_blank"
  message: "value must not be blank"
  expression: "this.trim() != ''"
}
```

`ConnectRpcRails::MessageValidatable` validates the decoded request after authentication and before the action. A violation answers `invalid_argument` with a `google.rpc.BadRequest`, one `FieldViolation` per failed rule: `field` is the path in the encoding the request used (`input.slug`, or `input.assignedSponsorshipIds` for JSON), `reason` is the rule `id`, and `description` is its message. The `id` is public the moment a client can read it, so it is never reused for another rule.

`config/initializers/protovalidate.rb` calls `Protovalidate.register_all` in `after_initialize`, so a broken CEL expression fails boot instead of the first request.

Validation covers what the message can know. A rule that needs the database stays in the model, and its failure is answered as an invalid record (next section).

## 4. Errors as problems

An error is an [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem, and the catalogue is a protobuf enum. Each value carries its published identifier and HTTP status through an enum value option (`problem.proto`):

```proto
PROBLEM_TYPE_NOT_FOUND = 3 [(problem_type) = {
  uri: "not-found"
  http_status: 404
}];
```

Ruby classes bind to a value (`app/models/errors.rb`), and a controller raises them:

```ruby
class NotFound < ApiError
  problem_type :PROBLEM_TYPE_NOT_FOUND
end

raise Errors::NotFound.new(detail: "No conference has the slug #{slug.inspect}.")
```

`Protobufable::Connect::ProblemRescuable` turns the exception into a Connect error. The HTTP status picks the Connect code (401 `unauthenticated`, 403 `permission_denied`, 404 `not_found`, 409 `aborted`, 412 `failed_precondition`, 422 `invalid_argument`, 500 `internal`), and the problem document rides in `details` as a packed `protobufable.ProblemDetails`. Its `type` is the `uri` appended to `https://sponsorships.rubykaigi.org/problems/` (`config/initializers/problem.rb`). Clients dispatch on `type`; the enum names never go on the wire. Titles live under `problem_details.titles` in `config/locales/`.

Two further pieces make an error actionable:

- `Errors::InvalidRecord` is what `save!` raises through `rescue_from ActiveRecord::RecordInvalid`. It publishes each model error on an attribute of the Input as a `BadRequest` violation of that field (`input.contact.email` for an autosaved association). Errors on `:base` or on attributes the Input lacks concern the request as a whole.
- `ConnectRequestInfo` appends a `google.rpc.RequestInfo` with the request ID to every Connect error a controller renders, and `ConnectExceptions` (`config/initializers/problem.rb`) does the same for an exception that escapes every controller. The SPA shows the request ID so a reported error leads to its log lines.

Identifiers and enum values are append-only: renaming one breaks every client that matches on it.

## 5. Responses from Alba resources

Controllers never assemble a response field by field. A resource under `app/resources/api/` builds each message, bound to its class with `with_protobuf`:

```ruby
class AdminPlanResource < Api::ApplicationResource
  with_protobuf Rk::SponsorApp::AdminPlan do
    attributes :id, :name, :rank, :capacity
    attributes closes_at: :timestamp, if: proc { |plan| plan.closes_at }
    attribute(:price) { |plan| plan.price.to_s }
  end
end
```

`Protobufable::AlbaBinding` compares the resource's attributes to the message descriptor when the class loads, so a field added to the `.proto` and forgotten in the resource, or the reverse, raises at boot rather than in production. `config/initializers/protobufable.rb` registers the `:timestamp` type, as a Timestamp field refuses an `ActiveSupport::TimeWithZone`.

Conventions that follow from proto3 semantics:

- A nullable column becomes an `optional` field and is left unset with an `if:` guard, or published as its empty value when the message holds a plain scalar. Reading code checks presence with `has_foo?`.
- Decimals are strings (`price`), as no float is exact for money.
- A resource's object is never an Array or Relation, since Alba treats any `Enumerable` as a collection. A grouped object is wrapped in a `Data` or a plain class.

A Create or Update request carries its `<Resource>Input` in a field named `input`, and the controller saves with `save!`. Format rules sit on the Input as `buf.validate` rules. A model keeps its own copy only while a HAML form still saves through it, and a spec such as `spec/proto/conference_input_spec.rb` holds both to the same verdict on sample values.

## 6. Messages in columns

A `jsonb` column can hold a message. `form_descriptions.fallback_options` is an `Rk::SponsorApp::Internal::FallbackOptions`:

```ruby
attribute :fallback_options,
  Protobufable::JsonType.new(Rk::SponsorApp::Internal::FallbackOptions, preserve_proto_fieldnames: true),
  default: -> { Rk::SponsorApp::Internal::FallbackOptions.new }
```

- Storage messages live in `proto/rubykaigi/sponsor_app/internal/` (package `rubykaigi.sponsor_app.internal`). They are never part of a service; `spec/proto/services_spec.rb` fails on any `.internal.` type an RPC reaches, and `buf.gen.es.yaml` leaves them out of `ui/src/gen`. The API publishes a message of its own, and controllers and resources copy between the two field by field. `spec/proto/fallback_options_spec.rb` compares the storage and API descriptors, rules included, so the copies cannot drift.
- `preserve_proto_fieldnames: true` stores `priority_human` where ProtoJSON would write `priorityHuman`. Every field is present in the document. Reads accept either spelling and ignore unknown fields.
- `ApplicationRecord` includes `Protobufable::ColumnValidatable`, which runs the message's `buf.validate` rules before save and adds one error on the attribute per violation. The rules that guard the Create RPC also guard a console write.
- Changing a message's shape migrates the stored documents in SQL, without loading models or messages (`db/migrate/20261012000000_wrap_fallback_options.rb`).
- Tapioca types the attribute `untyped`, so `sorbet/rbi/shims/form_description.rbi` declares the reader.

## 7. The SPA on generated TypeScript

`ui/` imports the TypeScript in `ui/src/gen` and talks to Rails through Connect-ES. Nothing about a request or response is written by hand on the client.

`ui/src/lib/rpc.ts` wraps a generated method in SWR. The method descriptor gives the input and output types, and the transport uses GET for `NO_SIDE_EFFECTS` methods:

```ts
const { data } = useRpc(AdminService.method.getConference, { conferenceSlug });
const save = useRpcMutation(AdminService.method.updateConference);
```

A `unauthenticated` answer sends the browser to the Rails sign-in page, which returns to the same path.

Errors are read from the details the server sent (`ui/src/lib/errors.ts`):

- `problemTypeOf(error)` maps the packed `ProblemDetails.type` back to the `ProblemType` enum.
- `requestIdOf(error)` reads `RequestInfo`.
- `fieldViolations(error, {prefix: "input."})` turns a `BadRequest` into TanStack Form errors keyed by field path. Form values are named after the Input's JSON fields (`fallbackOptions[1].value`), so a violation path is the name of its field.

A form saves in TanStack's `onSubmit` and hands a rejected save to `useSaveRejection` (`ui/src/lib/rejection.ts`) with the values it sent. The rejection keeps each error on its field while that value stands, so a blur leaves it and changing the field clears it, and it never stops the form from being sent again. `SaveErrorBanner` and `useFieldReveal` (`ui/src/routes/admin/FormParts.tsx`) show the count, the Connect code and the request ID, and scroll to the first field in error. CLAUDE.md ("SPA (ui/)") covers adding a screen.

`ui/src/lib/forms.ts` converts between input values and message fields: `int64` ids, `optional` strings and numbers, and `datetime-local` values to `Timestamp`. A value it cannot convert raises `RangeError`, and the form reports it without calling the server.

## 8. REST endpoints for HAML-side JSON

The HAML pages' scripts call plain JSON endpoints of their own, such as the expense report editor's line items and the asset uploader's upload session. The pattern for those is separate from Connect and lives on the HAML-side controllers.

- A request body is decoded by `ProtobufRequestBody` (`app/controllers/concerns/protobuf_request_body.rb`) into the message the action declares with `protobuf_body`, and the action reads `message`, as `app/controllers/expense_line_items_controller.rb` does. protobufable's tapioca DSL compiler types `message` as the declared class. A body that does not decode, names an unknown field or breaks the message's `buf.validate` rules answers 400 with `{"error": reason}` before the action runs. The message renders as `[FILTERED]` in logs.

  ```ruby
  protobuf_body Rk::SponsorApp::ExpenseLineItemPatch
  def update
    line_item.assign_attributes(line_item_attributes(message))
    # ...
  end
  ```

- An upload session and the fee calculation are messages, rendered with `render proto_json:`, a renderer protobufable registers: ProtoJSON with the `.proto` field names (snake_case, as the scripts already read them) and defaults left out. Each comes from a resource bound to its message: `AssetFileUploadResource` for the session `AssetFileSessionable#make_session` returns, and `ExpenseReportCalculationResource` (`app/resources/expense_report_calculation_resource.rb`) in `ExpenseReportsController#calculate`.
- The expense report itself has no message. `ExpenseReport#to_resource` renders it through a plain Alba resource with `render json:`, which keeps ActiveSupport's time encoding.
- The scripts parse a message with the TypeScript protoc-gen-es generates into `app/javascript/gen/`, whose `fromJson` fills the defaults back in. `buf.gen.javascript.yaml` lists the messages the scripts read or send, and only those are generated.
- `int64` id fields of those messages carry `jstype = JS_STRING`, so the TypeScript holds ids as strings, as they travel in JSON. Without it protoc-gen-es types an `int64` as `bigint`.

## 9. Known limits and trade-offs

These are facts about the design as it stands.

**Generated code in git**
- Every `.proto` edit changes `gen/` and `ui/src/gen`. The descriptor blob in `*_pb.rb` and `*_pb.ts` is one line, so a textual conflict inside it cannot be merged by hand. Resolve by taking either side and running `mise run --force gen`.
- Each RPC appends to its service's generated file, so branches adding RPCs to one service conflict there. Sections in `admin_service.proto` and in the `connect_service` block of `config/routes.rb` keep the hand-written side of that conflict to import lines.
- `gen:proto` deletes every `*_pb.*` before regenerating. Running it while anything boots Rails fails that process with "not in the descriptor pool".
- A `.proto` that fails to compile leaves `gen/` as it was, but a `buf generate` that fails after the delete leaves it empty until the next good run. Try template changes with `buf generate` into a scratch directory first.

**No hot reload**
- A `.proto` edit restarts Rails (see Dev loop). The cost is a few seconds per edit, and nothing in `app/` reloads differently.

**ProtoJSON naming**
- Connect JSON is canonical ProtoJSON, lowerCamelCase (`input.assignedSponsorshipIds`), because connect_rpc_rails encodes without options. Columns and browser REST JSON keep `.proto` names. A client moves between the two spellings by the endpoint it calls, and `fieldViolations` paths follow the request's encoding.
- Names are a one-way door for clients. Renaming a field renames its JSON key.
- An enum is a name in ProtoJSON and a `Symbol` or `Integer` in Ruby: an unknown value decodes as its number, so code mapping an enum narrows with `is_a?(Symbol)`.
- protoc-gen-es types `int64` as `bigint`. A field a plain-JSON client reads needs `jstype = JS_STRING`, and the TypeScript then sees a string.

**Presence**
- ProtoJSON decodes `null` on an `optional` field as unset, so `optional` alone cannot tell "clear this" from "leave this alone". A partial update names the fields it writes beside the message (`ExpenseLineItemPatch.field_mask`).
- That list is a `repeated string` of `.proto` field names rather than a `google.protobuf.FieldMask`: a FieldMask's JSON form is one comma-joined lowerCamelCase string whatever the encoder options, and upb refuses `_` in it.
- An unset `optional string` on an Input is a null column. An empty one is a value, which the field's rules judge, so an API client sending `""` for an optional URL fails its format rule.
- Repeated fields cannot be absent. A response that must say "absent" nests a wrapper message whose presence is the decision.

**Validation**
- A rule on the Input and a validation on the model are two copies while HAML saves through the model, and they are not byte-identical: RE2 anchors `^` and `$` on the whole text where Ruby anchors per line, and `.+?` accepts whitespace. The parity specs hold the samples they list and no more.
- Rules that need the database stay in Ruby and surface as `InvalidRecord`, so a request can pass protovalidate and still answer 422.
- protovalidate evaluates every rule on a field, so a size limit does not guard a costly CEL rule beside it. A quadratic CEL expression raises past its iteration budget, which no layer rescues, and answers 500. Guard it in the expression: `this.size() > 50 || this.all(...)`.
- protovalidate-cc rejects two-variable comprehensions and `lists.range`, so a rule cannot name a repeated element's position.
- Messages for standard rules are written for developers (`value does not match regex pattern`). A CEL rule carries a message for the person reading the form.
- protovalidate words its violations in English, while sponsor screens are localized. The sponsor forms check what their text needs before sending.

**Alba and types**
- `with_protobuf` catches drift at load time, so in development it also fires while a `.proto` and its resource are mid-edit.
- Sorbet ignores `.rbs`, so each message class needs a tapioca RBI, regenerated by `mise run gen`. `Protobufable::JsonType` has no signature tapioca can read, hence a shim per column.
- `T.` forms are not available (`sorbet-runtime` is not loaded), so request fields are typed with `#:` comments on the reading line.

**Dependencies**
- `protobufable` and `connect_rpc_rails` install from Git (`Gemfile`), each pinned to a commit of its main branch until a release carries what this app uses. `proto/protobufable/` is a vendored copy, and `spec/proto/vendored_protobufable_spec.rb` fails when it drifts from the gem.
- Connect routes are drawn only when `config.x.connect_rpc.enabled` is set, because CloudFront does not forward `Connect-Protocol-Version`, `Connect-Timeout-Ms` or `Sec-Fetch-Site`. The SPA is development only.
