# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SponsorApp2 is a Rails application for managing sponsorships for RubyKaigi conferences. It handles:

- Sponsor applications and approvals
- Asset file uploads (logos, etc.) to S3
- Email broadcasts to sponsors
- Ticket distribution via Ti.to integration
- On-site attendee registration
- GitHub integration for publishing sponsor data
- Staff management with restricted access per conference

## Architecture

### Core Domain Models

The application is built around these key models:

- **Conference**: Top-level container for an event (e.g., "RubyKaigi 2025")
  - Has many Plans, Sponsorships, Announcements, Broadcasts
  - Tracks application/amendment windows via timestamps
  - Can be hidden with invite code access
  - Integrates with Ti.to via `tito_slug`
  - Publishes to GitHub repo specified in `github_repo` (format: "owner/repo@branch:path")

- **Sponsorship**: Core entity representing a sponsor relationship
  - Uses `EditingHistoryTarget` concern to track all changes
  - Has polymorphic contacts (primary, billing) and requests (billing, customization, note)
  - Manages asset files, tickets, discount codes
  - Can be pending (not accepted), active (accepted and not withdrawn), or withdrawn
  - `ticket_key` provides secure access for sponsors to manage their sponsorship

- **Organization**: Represents a sponsoring company across multiple conferences
  - Identified by email domain
  - Reusable across years

- **Plan**: Sponsorship tier/package (e.g., Ruby, Platinum, Gold, Silver)
  - Defines price, word limits, booth eligibility, capacity
  - Can have `auto_acceptance` enabled
  - `rank` determines display order

- **Broadcast**: Email campaigns to sponsors
  - Creates BroadcastDelivery records per recipient
  - Status: created → preparing → ready as a job collects recipients, modifying while more are added, pending on dispatch, then sending → sent as delivery jobs run. Recipients change only while ready, and title and body are fixed from dispatch on
  - Tracks delivery status via Mailgun webhooks

### Authorization Pattern

- **Admin area** (`/admin`): GitHub OAuth authentication
  - Admin::ApplicationController checks staff access
  - Staff can have restricted access to specific conferences

- **User area** (`/conferences/:slug/sponsorship`): One-time email token authentication
  - SessionToken model provides time-limited access
  - Session claim URL sent via email

- **Reception area** (`/reception`): For on-site registration
  - Authenticated via conference `reception_key`

### Background Jobs

Uses Shoryuken (AWS SQS) for background processing:

- `CreateBroadcastDeliveriesJob`: Generate individual delivery records
- `DispatchBroadcastDeliveryJob`: Send individual emails
- `ProcessSponsorshipEditJob`: Handle post-save hooks (Slack notifications, etc.)
- `EnsureSponsorshipTitoDiscountCodeJob`: Sync discount codes with Ti.to
- `GenerateSponsorsYamlFileJob`: Publish sponsor data to GitHub
- `SponsorshipWelcomeJob`: Send welcome email to new sponsors

### AWS Integration

- **S3**: Asset file storage (logos, etc.)
  - Upload uses AssumeRole with `S3_FILES_ROLE`
  - Presigned URLs for secure uploads

- **SQS**: Background job queue via Shoryuken

### Frontend

- Rails views using HAML templates
- TypeScript/React components for interactive features:
  - `SponsorshipAssetFileUploader`: S3 upload with progress
  - `ReceptionCheckinForm`: On-site registration interface
  - `booth_assignments`: Admin UI for booth allocation
  - `broadcast_new_recipient_fields`: Dynamic form for email targeting

- Vite-based build via vite_rails gem
- Bootstrap 4 for styling
- `ui/`: a React SPA reimplementing the HAML screens on the Connect RPC API, development only (see "SPA (ui/)")

### External Integrations

- **GitHub**: Via Octokit gem
  - Publishes sponsor data (YAML/JSON) to repository
  - Used for authorization (staff list)

- **Ti.to**: Ticketing platform via API
  - Creates discount codes for sponsor attendees/booth staff
  - `TitoApi` model wraps API interactions

- **Mailgun**: Email delivery and webhook processing
  - Tracks delivery status (delivered, bounced, complained)

- **Slack**: Notifications via webhooks
  - Alerts on sponsorship edits, new applications

## Development Commands

### Dev Server

- Assume the dev server (Rails and Vite) is already up and running. Do not attempt to start them.
- The `Procfile` runs, under overmind and [trustless](https://github.com/sorah/trustless):
  - `web`: Rails on port 3000, at http://sponsor-app-rails.localhost:1355. Restarts when `gen/proto/ruby/` or `Gemfile.lock` changes.
  - `vite`: `bin/vite dev`, the assets of the HAML pages.
  - `ui`: the `ui/` Vite dev server, at http://sponsor-app.localhost:1355. It renders SPA paths and proxies every other request to Rails.
  - `proto`: regenerates `gen/` and `ui/src/gen` when a `.proto` changes, which restarts Rails and hot-reloads the SPA.
- If you encounter a connection error when accessing the dev server, halt and ask the human to check their server.
- If you modify files under `config/` that are not auto-reloaded (e.g., `config/initializers/`, `config/boot.rb`, `config/environment.rb`, `config/environments/`, `config/application.rb`), remind the human to restart the Rails server for changes to take effect.

### Setup

```bash
# Install dependencies
bundle install
pnpm install
mise run ui:install    # ui/ is a pnpm project of its own

# Setup database (requires Docker Compose for PostgreSQL)
docker-compose up -d
rails db:setup

# Start development servers
rails s                # Rails server on :3000
pnpm run watch         # Vite dev server with auto-reload
```

### Database

```bash
rails db:migrate                    # Run pending migrations
rails db:rollback                   # Rollback last migration
rails db:seed                       # Seed development data
rails db:reset                      # Drop, recreate, migrate, and seed
```

### Testing

```bash
rspec                               # Run all tests
rspec spec/models/sponsorship_spec.rb  # Run specific test file
rspec spec/models/sponsorship_spec.rb:42  # Run test at line 42
```

In a git worktree, `worktree:bootstrap` installs the root and `ui/` packages and the gems, and creates a test database of the worktree's own on the main checkout's compose db. Export the variables it prints:

```bash
mise trust && mise run worktree:bootstrap <slice>   # creates sponsor_app2_test_<slice>
export COMPOSE_PROJECT_NAME=sponsor-app DATABASE_URL=postgres://...   # as printed
```

### Asset Management

```bash
pnpm run build          # Production build of frontend assets
pnpm run format         # Format TypeScript/SCSS with Prettier
```

### Background Jobs

In development, jobs are defaulted to inline execution. So you do not need to run a separate worker.

### run Shoryuken worker

```bash
# Run Shoryuken worker locally
bundle exec shoryuken -R -C config/shoryuken.yml
```

### Code Quality

```bash
hk check                # RuboCop, Sorbet and other linters (also runs as the pre-commit hook)
mise run typecheck      # Sorbet type check (bundle exec srb tc)
mise run tapioca        # Regenerate RBIs after a Gemfile.lock, model or column change
```

### Type Checking

Sorbet with inline RBS comments (`#:`); see `docs/type-checking.md`.

- New Ruby files under `app/`, `lib/` and `config/` start at `# typed: strict`. Spec files carry no sigil.
- Never write `sig`, `T.let`, `T.must` or other `T.` forms in `.rb` files; `sorbet-runtime` is not loaded.
- Run `bundle` commands under the mise environment (`mise x -- bundle ...`); the lockfile has no `ruby` platform.

### Protocol Buffers

`proto/` is the schema of record (package `rubykaigi.sponsor_app`, Ruby namespace `Rk::SponsorApp`). buf generates Ruby and RBS from it into `gen/proto/ruby/`, the `sponsor_app-proto` path gem that Bundler loads at boot, and TypeScript into `ui/src/gen/` for the SPA. Generated files are committed.

```bash
mise run gen            # Run every generator: gen/ and ui/src/gen from proto/, then the message RBIs (boots Rails, needs no database)
mise run gen:proto      # Regenerate gen/ and ui/src/gen only
mise run lint:proto     # buf lint and buf format check
```

- Never edit generated files under `gen/` or `ui/src/gen/`. Edit `proto/`, run `mise run gen`, and commit its output with the `.proto` change. hk's pre-commit hook regenerates and stages it, and CI fails when it is stale.
- `buf.gen.yaml` generates the Ruby, and `buf.gen.es.yaml` the TypeScript with protoc-gen-es from `ui/node_modules`, so `mise run gen` runs `ui:install` first. The TypeScript also covers `google/rpc/error_details.proto` for the SPA's error handling. No Ruby is generated for `google/`, `buf/validate/` or `protobufable/`, whose gems ship it.
- `gen/proto/ruby/` also holds hand-written files the generator keeps: the gemspec and `lib/sponsor_app-proto.rb`.
- Message classes cannot be reloaded, as google-protobuf raises when a descriptor is registered twice. The Procfile's `proto` process regenerates `gen/` on `.proto` edits, and its `web` process restarts Rails when `gen/proto/ruby/` changes.
- Sorbet ignores the generated `.rbs`. Message types come from tapioca's Protobuf DSL compiler.
- `proto/protobufable/` is copied from the protobufable gem for buf. Do not edit it; refresh it when bumping the gem (`spec/proto/vendored_protobufable_spec.rb` checks it).

#### Messages in columns

A `jsonb` column can hold a message rather than a Hash: `form_descriptions.fallback_options` is an `Rk::SponsorApp::Internal::FallbackOptions`. Such messages live in `proto/rubykaigi/sponsor_app/internal/` (package `rubykaigi.sponsor_app.internal`, Ruby `Rk::SponsorApp::Internal`). They are storage, never part of a service: `spec/proto/services_spec.rb` fails on any `.internal.` type an RPC reaches, and `buf.gen.es.yaml` leaves them out of `ui/src/gen`. The API publishes a message of its own, and controllers and resources copy between the two field by field.

- In `rails c`, `FormDescription.first.fallback_options` is the message. A Hash or a ProtoJSON string assigned to the attribute is cast to it.
- The column stores ProtoJSON with every field present, in the `.proto` field names (`priority_human`). Reads accept the lowerCamelCase JSON names too and ignore unknown fields.
- `ApplicationRecord` includes `Protobufable::ColumnValidatable`, so the message's `buf.validate` rules run before save, one error on the attribute per violation. Ruby validations remain only for what needs a query.

To add one:

1. Define the message under `proto/rubykaigi/sponsor_app/internal/` and run `mise run gen`.
2. Declare `attribute :name, Protobufable::JsonType.new(Rk::SponsorApp::Internal::Foo, preserve_proto_fieldnames: true), default: -> { Rk::SponsorApp::Internal::Foo.new }` on the model.
3. Migrate the stored documents to the message's shape in SQL, without loading models or messages.
4. Declare the reader's type in `sorbet/rbi/shims/<model>.rbi`, as tapioca types the attribute untyped.

### Connect RPC API

Rails serves the services in `proto/` over the [Connect protocol](https://connectrpc.com/docs/protocol/) with connect_rpc_rails: `AdminService` for staff and `SponsorService` for sponsors, at `/rubykaigi.sponsor_app.<Service>/<Rpc>`. Unary only, by POST with JSON or binary protobuf, and by GET for RPCs marked `idempotency_level = NO_SIDE_EFFECTS`.

- Controllers live in `app/controllers/api/admin/` and `app/controllers/api/sponsor/`, one action per RPC. They inherit `Api::Admin::ApplicationController` or `Api::Sponsor::ApplicationController`, which authenticate with the HAML side's session cookie.
- Every RPC declares its policy right above its `def`: `authorize :any_staff`, `:unrestricted_staff` or `:conference` on `AdminService`, `authorize :sponsorship` or `:public` on `SponsorService`. Serving an RPC without one raises. `:conference` and `:sponsorship` read the request's `conference_slug`, which must be field 1.
- Responses are built by Alba resources in `app/resources/api/`, bound to their message with `with_protobuf`. Controllers never build a response field by field.
- Errors are problems: raise an `Errors::*` class from `app/models/errors.rb`, each typed by a `ProblemType` value in `proto/rubykaigi/sponsor_app/problem.proto`. Titles live under `problem_details.titles` in `config/locales/`. `buf.validate` rules on request fields are checked after authentication and answer `invalid_argument` with a `google.rpc.BadRequest`.
- Create and Update requests carry their `<Resource>Input` in a field named `input`. Save with `save!`: a record failing validation is answered `invalid_argument` with `PROBLEM_TYPE_INVALID_RECORD` (`Errors::InvalidRecord`), whose `google.rpc.BadRequest` names `input.<field>` for each error on an attribute of the same name, `input.<association>.<field>` for one on an autosaved association, such as `input.contact.email`, and `input.<association>_id` for one on an association the Input names by ID, such as `input.plan_id`.
- Format checks go on the Input as `buf.validate` rules. A model keeps its own copy only while a HAML form saves through it, and a spec holds the two to the same verdict on sample values, as `spec/proto/conference_input_spec.rb` does for `ConferenceInput` and `Conference`.
- An unset `optional string` on an Input is a null column. An empty one is a value, which the field's rules judge.
- A POST must send `Connect-Protocol-Version: 1`, and a request whose `Sec-Fetch-Site` or `Origin` names another origin is refused (`ConnectForgeryProtection`).
- Routes are drawn only when `config.x.connect_rpc.enabled` is set: always in development and test, and in production only with `SPONSOR_APP_CONNECT_RPC`, because CloudFront does not forward `Connect-Protocol-Version`, `Connect-Timeout-Ms` or `Sec-Fetch-Site`.

To add an RPC:

1. Declare it in its domain's section of `admin_service.proto` or `sponsor_service.proto`, with `<Service><Rpc>Request`/`Response` messages in `admin_<domain>.proto` or `sponsor_<domain>.proto`. Mark reads `NO_SIDE_EFFECTS`.
2. Run `mise run gen`.
3. Map it in the service's single `connect_service` block in `config/routes.rb`, in the same section.
4. Implement the action with its `authorize` policy, building the response with a bound resource.
5. Add a request spec under `spec/requests/api/` using `connect_call` from `spec/support/connect_helper.rb`. `spec/proto/services_spec.rb` fails until the RPC is routed to an action with a policy.

Calling it with curl:

```bash
# Sign in as staff: claim a session token, keeping the session cookie
handle=$(bin/rails runner 'puts SessionToken.create!(staff: Staff.first!).handle')
curl -c jar "http://sponsor-app.localhost:1355/session/claim/$handle"

# POST, JSON
curl -b jar -H 'Content-Type: application/json' -H 'Connect-Protocol-Version: 1' \
  -d '{"conferenceSlug": "rubykaigi2048"}' \
  http://sponsor-app.localhost:1355/rubykaigi.sponsor_app.AdminService/GetConference

# GET, for an RPC without side effects
curl -b jar 'http://sponsor-app.localhost:1355/rubykaigi.sponsor_app.AdminService/GetConference?connect=v1&encoding=json&message=%7B%22conferenceSlug%22%3A%22rubykaigi2048%22%7D'
```

An error is a JSON body `{"code", "message", "details"}`, each detail a protobuf message named by `type` and encoded in unpadded base64 under `value`.

These recipes work on both hosts. A session cookie belongs to the host that set it, so http://sponsor-app.localhost:1355 and http://sponsor-app-rails.localhost:1355 each need their own sign-in.

### SPA (ui/)

`ui/` is a standalone pnpm project, not part of the root `package.json`: React, React Router (data mode), SWR, TanStack Form, [Kumo](https://github.com/cloudflare/kumo) on Tailwind CSS 4, and Connect-ES on the code generated into `ui/src/gen/`. It is development only. Production serves the HAML pages, and the Docker image leaves `ui/` out.

The `ui` Vite dev server is the SPA's origin, http://sponsor-app.localhost:1355. Its own files live under `/_ui/`. A page load (`Sec-Fetch-Dest: document`) of a path listed in `ui/src/routes/paths.ts` gets the SPA. Every other request goes to Rails (`SPONSOR_APP_RAILS_URL`, default http://127.0.0.1:3000) with its `Host` untouched: RPCs, sign-in, `/vite-dev/`, downloads and each HAML page the SPA does not implement yet. http://sponsor-app-rails.localhost:1355 keeps serving every page as HAML.

```bash
mise run ui:install     # pnpm install --frozen-lockfile in ui/
mise run ui:typecheck   # tsc --noEmit (TypeScript 7)
mise run ui:test        # node:test suites (*.test.ts), run with Node's type stripping
mise run ui:build       # vite build, to check the bundle
cd ui && pnpm run format  # oxfmt
```

To add an SPA screen:

1. Add its path pattern to its domain's section of `ui/src/routes/paths.ts`. Until a path is listed there, the dev server keeps sending it to Rails. A pattern ending in `:id` also matches a HAML `new` page beside it; list that page in `RAILS_PATHS` there until the SPA renders it.
2. Add a route module under `ui/src/routes/` and wire it into its domain's section of `ui/src/router.tsx` with `lazy`, under the `/admin` tree or the sponsor tree.
3. Fetch with `useRpc(AdminService.method.getConference, {conferenceSlug})` and mutate with `useRpcMutation` from `ui/src/lib/rpc.ts`. When there is no data, throw the error so the route's error boundary shows its Connect code, problem type and request ID.
4. Link with Kumo's `Link`, `LinkButton` or `Sidebar.MenuButton` and an `href`, or, for a `Tabs` tab, set `render` to `useLinkComponent()`'s component with an `href` and `nativeButton: false` (`ui/src/routes/admin/AnnouncementDetail.tsx`). A path in `paths.ts` navigates in place, and any other is a full page load of the HAML page.

- `ui/src/lib/errors.ts` reads Connect error details: `fieldViolations` turns a `google.rpc.BadRequest` into TanStack Form errors, `problemTypeOf` maps a problem back to `ProblemType`, `requestIdOf` reads `google.rpc.RequestInfo`.
- A form saves in TanStack Form's `onSubmit`, with `validators: {onChange: rejection.validate}` from `useSaveRejection` (`ui/src/lib/rejection.ts`). When the save fails it calls `rejection.reject(formApi, value, fieldViolations(error, {prefix: "input."}))`, `value` being what `onSubmit` was given. Its `<form noValidate onSubmit>` calls `rejection.submit(form)`. The errors stay on their fields until each field's value changes, and the form can be sent again meanwhile. Form values named after the Input's JSON fields make each violation's path, such as `fallbackOptions[1].value`, the name of its field (`ui/src/routes/admin/FormDescriptionEditor.tsx`). After saving, revalidate what changed with `mutate((key) => isRpcKeyOf(key, method))`.
- An editor shows a rejected save beside its Save button and scrolls to the first field in error, as `ui/src/routes/admin/ConferenceEditor.tsx` does. It declares a `FieldLayout` labelling its fields in layout order (`CONFERENCE_LAYOUT`) and sets `data-field` to the field's path on each input or its wrapper. When the save fails it reveals the first of `erroredFields` from `ui/src/lib/fieldErrors.ts` with `useFieldReveal`, and the save area's `form.Subscribe` feeds the form's `errorMap.onChange`, those fields and the last save error to `SaveErrorBanner`, both from `ui/src/routes/admin/FormParts.tsx`. A field showing a list's errors, such as a tag input or multi-select, reads them with `errorsAt(fieldMeta, path, {items: true})` from `ui/src/lib/fieldErrors.ts`.
- `ui/src/lib/forms.ts` converts between input values and message fields: int64 IDs, int32 numbers, `datetime-local` timestamps in the browser's time zone, and `optional` strings and int32s. An emptied required number is sent unset, as its Input declares the field `optional` and marked required, so the server reports it missing. A value no int32 can hold, such as 1.5, raises `RangeError`, which the form reports on that field without calling the server (`planInputFrom` in `ui/src/routes/admin/planForm.ts`). `idFromParam` reads a route's `:id`, giving undefined for a segment that is no ID so the screen can answer `NotFound`.
- A file goes from the browser straight to S3 (`ui/src/routes/admin/expense_report/upload.ts`): `CreateExpenseFileUpload` records a pending `ExpenseFile` and returns a presigned POST, the browser posts the file with its SHA-256 checksum, and `CompleteExpenseFileUpload` records the version S3 answered with. A preview or download links to the Rails page that redirects to S3, such as `.../expense_files/:id`, which the dev server proxies.
- An RPC answering `unauthenticated` sends the browser to the Rails sign-in page, which brings it back afterwards. RPCs are same-origin and need no CSRF token.
- A screen showing what a background job moves on, such as a broadcast's status, passes `useRpc` a `refreshInterval` function that polls until the job is done (`refreshIntervalFor` in `ui/src/routes/admin/broadcastView.ts`).
- A group of fields two forms share is one form field holding an object, rendered by a controlled component that reads the errors below it with `errorsUnder` from `ui/src/lib/fieldErrors.ts` and sets `data-field` on each input (`ui/src/routes/admin/RecipientFilterFields.tsx`).
- Navigate from code with `useGoTo()` from `ui/src/lib/navigation.ts`. It navigates in place only to a path in `paths.ts` and loads any other as a page, where the router would render its NotFound instead of the HAML page.
- `ui/src/lib/SandboxedHtml.tsx` renders staff-authored HTML, such as announcements and notes, in a frame that runs no script.
- Code imported by a `*.test.ts` must be erasable TypeScript with `.ts` import extensions, as Node strips the types without compiling. tsconfig's `erasableSyntaxOnly` enforces the former; a missing `.ts` extension surfaces only when `mise run ui:test` loads the module.

#### Sponsor screens in the sponsor's language

The staff area is English only. The sponsor tree shows Rails' own locale texts, which `SponsorService.GetTranslations` serves in the locale the browser chose.

- It serves only the scopes listed in `SponsorTranslations::SCOPES` (`app/models/sponsor_translations.rb`), in sections per domain like the service's. Never list `admin.*` or a mailer's scope.
- `SponsorLayout` provides the texts through the React Context in `ui/src/lib/i18n.tsx`. Read them with `const t = useT()`, never through props:
  - `t("root.index.sponsor_conference", {conference: name})` fills `%{conference}`, and `org_name` is filled in already.
  - `t(key, {count})` picks the `.zero`, `.one` or `.other` form as I18n does.
  - `t.rich(key, {link: <Link href="…">…</Link>})` puts elements in place of variables.
  - `t.html(key, vars)` returns HTML for a key ending in `_html` and escapes every other text and every variable.
  - `t.dateTime(timestamp)` shows a time in the browser's time zone, naming the zone. The HAML pages print UTC.
  - A missing key renders as the key itself.
- A sponsor screen writes no user-facing string itself. Reuse the HAML page's keys, adding their scope to `SCOPES`, or add texts only the SPA shows under `sponsor_ui.<domain>` in both `config/locales/en.yml` and `ja.yml`. `spec/requests/api/sponsor/locale_spec.rb` fails on a `sponsor_ui` key missing from `ja.yml`.
- The SPA's page loads never reach Rails, so the language menu calls `SponsorService.SetLocale`, and `SponsorLayout` applies a `?hl=` the page was loaded with the same way before dropping it from the URL.

## Development Notes

### Authentication Backdoor

In development, visit http://sponsor-app.localhost:1355/admin/session/new and use the "Development Backdoor" form to sign in without GitHub OAuth. It returns to the `back_to` path when there is one, as the SPA's sign-in redirect sets. Sign in on http://sponsor-app-rails.localhost:1355 separately to use the HAML pages there.

### Email Testing

In development, emails are captured by Letter Opener gem. Use either method to view sent emails:

- Visit http://sponsor-app.localhost:1355/letter_opener
- Check `tmp/letter_opener` directory and its files

### Environment Variables

Required for full functionality (see README.md for complete list):

- `DATABASE_URL`: PostgreSQL connection
- `ORG_NAME`: Organization name (e.g., "Ruby no Kai")
- `DEFAULT_EMAIL_ADDRESS`, `DEFAULT_EMAIL_HOST`, `DEFAULT_URL_HOST`: Email configuration
- `S3_FILES_REGION`, `S3_FILES_BUCKET`, `S3_FILES_PREFIX`, `S3_FILES_ROLE`: AWS S3
- `GITHUB_REPO`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `GITHUB_APP_ID`, `GITHUB_CLIENT_PRIVATE_KEY`: GitHub integration
- `SLACK_WEBHOOK_URL`: Slack notifications
- `SENTRY_DSN`: Error tracking (optional)

### Editing History

Models including `EditingHistoryTarget` concern automatically track all changes:
- Sponsorship changes create SponsorshipEditingHistory records
- SponsorEvent changes create SponsorEventEditingHistory records
- Exhibition changes create ExhibitionEditingHistory records
- `staff` attribute should be set before save to track who made changes
- History includes full snapshot via `to_h_for_history` method
- `AdminService.ListSponsorshipEditingHistory` and `ListSponsorEventEditingHistory` publish each history as an `EditingHistoryEntry`, and each of its Hashdiff rows (read through `EditingHistoryChange`) as an `EditingHistoryEntry.Change` holding `google.protobuf.Value`s, as a snapshot has no fixed schema
- `AdminService.UpdateBoothAssignment` (`BoothAssignment#assign!`) saves every sponsorship whose booth it changes in one transaction, and enqueues one `ProcessSponsorshipEditJob` per saved history only after it commits

## Deployment

Deployed to AWS using:
- **App Runner** for the web application
- **ECS Fargate** for background workers (Shoryuken)
- Terraform configuration in `tf/` directory
- Hako (ECS deployment tool) configurations in `deploy/hako/`
- CI/CD via GitHub Actions (`.github/workflows/ci.yml`)
  - Builds Docker image on push to master
  - Runs migrations via Hako oneshot
  - Deploys worker to ECS, then web to App Runner

### Deployment Commands

```bash
# Deploy worker (from deploy/)
cd deploy
bundle exec hako deploy --tag <git-sha> ./hako/sponsor-app-worker.jsonnet

# Deploy web app (from tf/)
cd tf
terraform apply -target=aws_apprunner_service.prd
```

## Code Conventions

### Rails Conventions

- Use `fetch` for required hash keys or params
- Keyword arguments for methods with multiple parameters
- Service objects live in `app/models/` (e.g., `TitoApi`)
- Background jobs use ActiveJob with Shoryuken adapter

### Naming

- Models use singular names (Sponsorship, Conference)
- Controllers use plural names (SponsorshipsController)
- Routes use `:slug` param for conferences instead of `:id`
- Admin controllers namespaced under `Admin::`

### Validations and State Management

- Use scopes for common queries (e.g., `Sponsorship.active`, `Conference.application_open`)
- Boolean state tracked via timestamps (e.g., `accepted_at`, `withdrawn_at`)
- Virtual attributes for boolean accessors (e.g., `accepted?`, `accepted=`)

### I18n

- Default locale: `:en`
- Available locales: `[:en, :ja]`
- Locale stored per sponsorship for email communications
- Form descriptions localized per conference
- Admin interfaces don't need localization. Embed text directly into views.
- The SPA's sponsor screens read the same locale files, see "Sponsor screens in the sponsor's language".
