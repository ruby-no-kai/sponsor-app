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
- If you encounter a connection error when accessing the dev server, halt and ask the human to check their server.
- If you modify files under `config/` that are not auto-reloaded (e.g., `config/initializers/`, `config/boot.rb`, `config/environment.rb`, `config/environments/`, `config/application.rb`), remind the human to restart the Rails server for changes to take effect.

### Setup

```bash
# Install dependencies
bundle install
pnpm install

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
# No formal linter configured; follow existing code style
```

## Development Notes

### Authentication Backdoor

Set `BACKDOOR_SECRET` environment variable, then visit:
```
http://localhost:3000/admin/session/new?backdoor=BACKDOOR_SECRET&login=YOUR_GITHUB_LOGIN
```

This bypasses GitHub OAuth for local development.

### Email Testing

In development, emails are captured by Letter Opener gem. Use either method to view sent emails:

- Visit http://localhost:3000/letter_opener
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
- Exhibition changes create ExhibitionEditingHistory records
- `staff` attribute should be set before save to track who made changes
- History includes full snapshot via `to_h_for_history` method

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
