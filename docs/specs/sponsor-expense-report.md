# sponsor-expense-report

## Summary

Allow custom sponsors to report their programme-essential expenses for their custom sponsorship package. Expenses are offset against the sponsorship tier fee; organizers review and approve each report before post-conference invoicing at the deducted price.

## Motivation

Custom sponsors propose unique programmes (drinkups, Wi-Fi sponsorship, hack spaces, etc.) and choose an equivalent standard tier matching their budget. Their programme-essential expenses are offset against the tier fee — only programme-essential expenses are accepted, not self-promotion materials. If expenses exceed the tier price, no reimbursement occurs; it is just an offset.

We currently collect these expense reports using Google Sheets, and formats vary by sponsor, especially when sponsors can't share files externally. This makes it hard to track and review expenses consistently. By providing a built-in expense reporting feature, we can streamline the process for both sponsors and organizers.

## Explanation

### Eligibility

Only custom sponsorships (`sponsorship.customization == true`) can create expense reports. Each sponsorship has at most one expense report (one-to-one relationship).

### Scenarios

- Sponsor can create an expense report.
- Sponsor can draft expense line items to illustrate the usage and the budget during the sponsorship period.
- Sponsor can submit the expense report for review.
- Sponsor can upload files for each line item.
- Sponsor can upload files to a specific line item.
- Sponsor can upload files in bulk by dropping files onto the page:
  - Dropping files on the left pane uploads them as unlinked files (added to the file pool).
  - Dropping files on the center pane uploads and links them to the currently selected line item.
- Sponsor can upload image (jpeg, png, webp) and PDF files.
- Sponsor can list files, and can see which files are not attached to any line items.
  - List pane includes a section for unused files.
- Sponsor can reuse the same file across multiple line items if needed.
- Sponsor can attach files to a line item via a picker that lists available files from the uploaded pool.
- Sponsor can reorder line items by drag and drop (stored as `position` integer).
- Each line item has `amount` (net, without tax), `tax_rate` (decimal, nullable), and `tax_amount` (decimal). When `tax_rate` is present, the server calculates `tax_amount = amount * tax_rate`. When `tax_rate` is nil, the sponsor enters `tax_amount` manually.
- Multiple JCT tax rates are supported (configured as `[1/10r, 8/100r, 0/1r]` — 10%, 8%, 0%).
- Frontend provides a tax input mode selector per line item:
  - "Entered amount excludes tax, calculate with N%" — sends amount directly as net, with tax_rate.
  - "Entered amount includes tax of N%" — frontend back-calculates net amount before sending, with tax_rate.
  - "Tax does not apply" — sends tax_rate = 0.
  - "I'll enter amount manually" — tax_rate = nil, sponsor enters both amount and tax_amount directly.
  - The mode is a frontend-only concern; the database always stores amounts as exclusive (net + separate tax).
- The `preliminal` flag on line items indicates planned budget usage (illustrative). Preliminal items are included in the total — the flag is informational only.
- Organizer reviews line items individually but approves or rejects the entire report as a whole (no per-line-item status tracking).
- Organizer can leave a comment on an expense report when reviewing it, to provide feedback to the sponsor.
- Organizer has access to the same edit view as sponsors, to allow minor corrections to the report if needed.
- Sponsor and Organizer can see the total amount (without tax) and total tax amount. Both are auto-calculated from line items and stored on ExpenseReport.
- Sponsor cannot edit an approved expense report.
- Sponsor cannot edit a submitted expense report. To make changes, the sponsor can withdraw the submission (returning to draft), or the organizer can reject it.
- Organizer can see the list of reports across sponsors from the admin page. Table shows: sponsor name, plan name, total amount (without tax), and the difference between the sponsorship fee and the report total.
  - Sponsorship fee = `plan.price + plan.price_booth` (if `booth_assigned`). Uses actual booth allocation, not just the request.
- System sends Slack notification to organizer feed channel on report submission. Uses `:receipt:` emoji via `SlackWebhookJob` with `:feed` hook_name, includes sponsor name, total amount, and link to admin expense report view.

### Status Transitions

- `draft` → `submitted`: Sponsor creates a submission (`ExpenseReportSubmissionsController#create`).
- `submitted` → `approved`: Organizer creates a review with `action: approve`.
- `submitted` → `rejected`: Organizer creates a review with `action: reject` (with comment).
- `rejected` → `draft`: Automatic when the sponsor makes any edit to the report. No separate API call required.

Organizer edits (minor corrections) do not change the report's status. Review comments are stored on `ExpenseReportReview` records (not on ExpenseReport), providing a full history of review actions.

### UI Layout

- Report editor and viewer is a 3-column (3-pane) view, similar to a typical reimbursement report app.
  - **Left pane** (iOS tableview-style):
    - Line items section: each item shows title + amount, with a "preliminal" tag/label for preliminal items.
    - Unlinked files section (below line items): small section header, each file shows filename only. Clicking selects for preview.
  - **Center pane**: details of the selected line item, including file attachments (picker to attach from uploaded pool). Tax input mode selector per line item.
  - **Right pane**: file preview — images inline via `<img>`, PDFs via `<iframe>`. Clicking an attached file in the center pane switches the preview.
- Drop zones: dropping files on the left pane adds them as unlinked files; dropping on the center pane uploads and links to the selected line item. Visual drop zone indicators appear when a file is being dragged.
- Report editor/viewer has 80vh height by default.
- Single React component for both sponsor and admin views, with admin-specific controls rendered conditionally via a `role` prop passed as a data attribute.
- Admin review form (approve/reject buttons + review comment field) renders below the 3-pane editor.
- Sponsor view shows the latest review comment (read-only) when the report is rejected, so the sponsor can reference feedback while editing.
- When the report is approved or submitted (for sponsors), the view is read-only: same 3-pane layout with all inputs disabled. Sponsor can still browse and preview files.
- Entry point: "Expense Report" section on the sponsor's sponsorship show page, visible only for custom sponsorships. Shows current status if report exists, or a "Create Expense Report" button if none.
- File upload report-back: browser sends `filename` and `content_type` alongside `version_id` and `extension` in the update request.
- When the report is in submitted status, any edit (including organizer corrections) refreshes the `ExpenseReportSubmission` snapshot to keep it in sync with the live report.

## Prior Art

None.

## Security and Privacy Considerations

- Expense reports and files are strictly isolated per sponsorship. Each sponsor can only access their own report and files. Admin staff can access all.
- File uploads use the existing AssetFileUploadable STS-based presigned URL pattern. Content-type validation is browser-side only (via `accept` attribute on file input).
- File downloads require authentication: sponsor session (owning sponsorship) or admin staff. Served via presigned S3 URLs generated on demand.

## Mission Scope

### Out of scope

- Admin-only views do not require i18n.

### Expected Outcomes

- Custom sponsors can create, edit, and submit expense reports through the sponsor portal.
- Organizers can review, approve, or reject expense reports from the admin interface.
- The admin expense report list gives organizers a complete view of all custom sponsorships and their expense status, including the offset against sponsorship fees.
- Receipt files (images, PDFs) are uploaded directly to S3 and previewable inline.
- Multiple JCT tax rates are supported with a user-friendly tax input mode selector.
- A full audit trail of submissions and reviews is maintained via snapshot records.
- Slack notification alerts organizers when a report is submitted.
- Plan model gains machine-readable `price` and `price_booth` columns for fee calculation.

### Test Coverage

Key areas to test (RSpec, following existing patterns):

**Model specs:**
- ExpenseReport: status transitions, total recalculation from line items, revision increment on submit, validation (one-per-sponsorship, custom-only)
- ExpenseLineItem: amount/tax_amount validations (>= 0), tax_amount server calculation (when tax_rate present vs nil), position ordering, title required
- ExpenseReportSubmission: snapshot creation, snapshot refresh on edit while submitted, snapshot freeze after review
- ExpenseReportReview: action enum, association with ExpenseReportSubmission, ExpenseReport status side effect
- ExpenseFile: AssetFileUploadable integration, S3 object key prefix, hard delete with S3 cleanup, cascade delete of join records

**Request specs:**
- Sponsor authorization: only custom sponsorships can create reports; isolated per sponsorship
- Status transition guards: submit only from draft, approve/reject only from submitted, withdraw only from submitted, auto-draft on editing rejected
- Admin authorization: staff access, review creation, admin edits don't change status
- File access control: owner + staff only
- Calculate endpoint: returns correct tax rates and fee breakdown

## Implementation Plan

### Database Design

- **`ExpenseReport`**: belongs to `Sponsorship` (one-to-one). Columns: `total_amount` decimal (without tax, auto-calculated), `total_tax_amount` decimal (auto-calculated), `status` (draft/submitted/approved/rejected), `revision` integer (default 0, incremented on each submission). No `tax_rate` column (rates are per line item). No `review_comment` column (review history lives in `ExpenseReportReview`).
- **`ExpenseReportSubmission`**: belongs to `ExpenseReport`. Created on each submission. Columns: `revision` integer (matching ExpenseReport.revision at creation), `data` jsonb (full snapshot of the report matching API response format). The snapshot is kept updated while the report is submitted (e.g., organizer minor edits) until a review is created and linked. After review, the snapshot is frozen. Purely for backend audit — not exposed in UI.
- **`ExpenseReportReview`**: belongs to `ExpenseReportSubmission`. Columns: `action` enum (approve/reject), `comment` text (nullable), `staff_id` FK (references Staff, optional). Provides an audit trail of all review actions. The latest review's comment is displayed to the sponsor. The UI reads from the live ExpenseReport, not from the submission snapshot.
- **`ExpenseFile`**: uses `AssetFileUploadable` concern, belongs to `Sponsorship`. Stores uploaded receipt files (images and PDFs). Max file size: 20MB. Accepted content types: image/jpeg, image/png, image/webp, application/pdf. S3 prefix: `c-{conference_id}/expenses/s-{sponsorship_id}/`. Additional columns: `filename` string (original upload filename from browser), `content_type` string. Hard-deletes from both DB and S3 (with cascade delete of `ExpenseLineItemFile` join records).
- **`ExpenseLineItem`**: belongs to `ExpenseReport`. Columns: `title` string (required, short label), `notes` text (optional, longer details), `amount` decimal (>= 0, net without tax), `tax_rate` decimal (nullable; nil = manual entry, otherwise from configured rates), `tax_amount` decimal (>= 0; server-calculated when tax_rate present, user-provided when nil), `preliminal` boolean (default false), `position` integer.
  - References `ExpenseFile`s as receipts via **`ExpenseLineItemFile`** join table (many-to-many).
- **`ExpenseLineItemFile`**: join table. Columns: `expense_line_item_id` FK, `expense_file_id` FK. Unique index on `(expense_line_item_id, expense_file_id)`.
- **`Plan` additions**: Add `price` decimal (default 0, not null) and `price_booth` decimal (default 0, not null) for machine-readable pricing. The existing `price_text` column remains for display.

**Database indexes:**
- `expense_reports`: unique index on `sponsorship_id` (one-to-one).
- `expense_report_submissions`: unique index on `(expense_report_id, revision)`. FK index on `expense_report_id`.
- `expense_report_reviews`: FK index on `expense_report_submission_id`, `staff_id`.
- `expense_files`: FK index on `sponsorship_id`. Index on `handle` (from AssetFileUploadable).
- `expense_line_items`: FK index on `expense_report_id`. Index on `(expense_report_id, position)`.
- `expense_line_item_files`: unique index on `(expense_line_item_id, expense_file_id)`. FK indexes on both columns.

### API Design

User-facing routes (nested under `conferences/:slug`):

```ruby
resource :sponsorship do
  resource :expense_report, only: [:create, :update, :show] do
    member do
      get :calculate  # returns tax_rates config and sponsorship fee calculation
    end
    resources :line_items, controller: 'expense_line_items', only: [:create, :update, :destroy]
    resource :submission, controller: 'expense_report_submissions', only: [:create, :destroy]
  end
end
resources :expense_files, only: [:create, :update, :show, :destroy] do
  member do
    post :initiate_update
  end
end
```

Admin routes (nested under `admin/conferences/:slug`):

```ruby
resources :expense_reports, only: [:index]  # standalone list of all reports for the conference
resources :sponsorships do
  resource :expense_report, only: [:show, :update], controller: 'expense_reports' do
    member do
      get :calculate
    end
    resources :reviews, controller: 'expense_report_reviews', only: [:create]
  end
end
```

**Sponsor actions:**
- `ExpenseReportSubmissionsController#create`: submits the report (draft → submitted).
- `ExpenseReportSubmissionsController#destroy`: withdraws submission (submitted → draft), if needed.
- Editing a rejected report automatically transitions it to draft (no separate API call).

**Admin actions:**
- `Admin::ExpenseReportReviewsController#create`: creates a `ExpenseReportReview` record (approve or reject with comment). Updates `ExpenseReport.status` as a side effect.

**Admin pages:**
- Standalone expense report list at `/admin/conferences/:slug/expense_reports`. Lists all custom sponsorships for the conference — including those without a report (shown as "No report") — with sponsor name, plan, status, total amount, and offset from sponsorship fee.
- Individual sponsorship show page (`admin/sponsorships/:id`) links to the expense report if one exists.

**Response format:**
- `expense_report#show` responds to HTML (renders page with React mount point) and JSON (full report with all line items, files, and `latest_review: { action, comment, created_at }`). React fetches data via JSON after mounting.
- `expense_report#create` creates an empty draft report. Sponsor adds line items through the editor.
- `expense_report#calculate` returns available `tax_rates` and the sponsorship fee breakdown (`plan.price`, `plan.price_booth`, `booth_assigned`, total fee). Separate endpoint to handle frequent requests from the frontend.
- All mutation endpoints (`expense_report#create`, `#update`, `expense_line_items#create/#update/#destroy`, submission, review) return the full report JSON so the React component can refresh its entire state.

**File routes:**
- Expense files are parallel to sponsorship (like existing asset files), not nested under expense_report, because files belong to the sponsorship and can be uploaded independently.
- `expense_files#destroy` hard-deletes the file from both DB and S3.

### Frontend

- Use TypeScript + React, embedded in a Rails HAML view via `createRoot`.
  - i18n strings passed via data attributes on the container element (following existing codebase pattern, e.g. `user_sponsorships_form.ts`).
- Bulk file upload: frontend handles drop zone via native HTML5 File API (`dragover`/`drop` events + `DataTransfer`), creates `ExpenseFile` records and uploads to S3 sequentially via the existing `AssetFileUploadable`/`AssetFileUploader` pattern.
- Line item reordering: use `@dnd-kit/core` + `@dnd-kit/sortable` for drag-and-drop.
- File preview (right pane): images rendered inline via `<img>`, PDFs via `<iframe>`. Presigned URLs fetched on demand via `expense_files#show` redirect (not included in report JSON to avoid expiry). Clicking an attached file in the center pane switches the right pane preview.
- No feature flag — expense report feature is always available for custom sponsorships.

**JavaScript libraries to add:**
- `@tanstack/react-form` — TypeScript-first headless form library for per-line-item field state and validation
- `@dnd-kit/core` — core drag-and-drop engine for React
- `@dnd-kit/sortable` — sortable list preset for line item reordering
- `@dnd-kit/utilities` — CSS transform utilities for smooth drag animations

**Ruby gems to add:**
- `alba` — JSON serializer for expense report API responses (replaces jbuilder for this feature). Use `Alba::Resource` classes in `app/resources/`.

### Callbacks and Model Methods

**Callbacks (3 total, all invariants):**

1. `ExpenseLineItem before_save` — calculate `tax_amount = amount * tax_rate` when `tax_rate` is present. Skipped when `tax_rate` is nil (manual entry).
2. `AssetFileUploadable before_validation` — generate `handle` if blank (existing concern behavior).
3. `AssetFileUploadable after_destroy` — hard-delete S3 object (new addition to the concern, benefits all AssetFileUploadable models).

No other callbacks are expected. Specifically, the following are handled by explicit model method calls, not callbacks:
- Total recalculation (not a line item after_save/after_destroy callback)
- Status transitions (not before_save or after_save callbacks)
- Revision increment (part of `submit!`, not a callback)
- Submission snapshot refresh (not an after_save callback)
- Position assignment (not a before_create callback)

**Model methods:**

| Model | Method | Saves? | Description |
|---|---|---|---|
| `ExpenseReport` | `recalculate_totals` | No | Sum line items → set `total_amount`, `total_tax_amount` |
| `ExpenseReport` | `submit!` | Yes (transaction) | Guard draft, increment revision, create submission with snapshot, set status, save |
| `ExpenseReport` | `withdraw_submission!` | Yes | Guard submitted, set status to draft, save |
| `ExpenseReport` | `reopen_if_rejected` | No | Set status to draft if rejected, no-op otherwise |
| `ExpenseReport` | `build_snapshot_data` | No | Return report as JSON hash for submission snapshot |
| `ExpenseReport` | `refresh_submission_snapshot` | No | Update current submission's `data` jsonb if submitted |
| `ExpenseReportReview` | `.create_for!(submission, ...)` | Yes (transaction) | Create review, freeze snapshot, update report status, save all |
| `ExpenseLineItem` | `assign_next_position` | No | Set position to `report.line_items.maximum(:position).to_i + 1` |

**Controller patterns:**

```ruby
# Line item create/update/destroy
@report.reopen_if_rejected if current_sponsorship
@report.recalculate_totals
@report.refresh_submission_snapshot
@report.save!

# Submit (sponsor)
@report.submit!

# Withdraw (sponsor)
@report.withdraw_submission!

# Review (admin)
ExpenseReportReview.create_for!(@submission, action:, comment:, staff:)
```

Non-saving methods are batched with a single `save!` in the controller. Methods that create child records (`submit!`, `create_for!`) wrap their own transaction.

### Configuration

- `config/initializers/expense_report.rb`: add `Rails.configuration.x.expense_report.tax_rates` as an array of available tax rates. Default: `[1/10r, 8/100r, 0/1r]` (10%, 8%, 0% JCT rates). Stored as Rationals in config, converted to decimals for DB storage and JSON serialization.

## Current Status

Implementation in progress. Implementors MUST keep this section updated as they work.

### Implementation Checklist

Each group corresponds to a reasonably-sized commit.

**1. Plan pricing**
- [x] Migration: add `price` and `price_booth` decimal columns to `plans` table
- [x] Admin form: add `price` and `price_booth` fields to plans form and permit in controller
- [ ] ~Model: update `Plan` with `price`, `price_booth` accessors~ (not needed — AR provides accessors)
- [ ] ~Seeds: update Plan seeds with numeric `price`/`price_booth` values~ (defaults to 0, editable via admin)

**2. Dependencies and configuration**
- [x] Gemfile: add `alba` gem
- [x] package.json: add `@tanstack/react-form`, `@dnd-kit/core`, `@dnd-kit/sortable`, `@dnd-kit/utilities`
- [x] Config: `config/initializers/expense_report.rb` with tax_rates

**3. Expense report models and migrations**
- [x] Migration: create `expense_reports`, `expense_report_submissions`, `expense_report_reviews`, `expense_files`, `expense_line_items`, `expense_line_item_files` tables
- [x] Model: `ExpenseReport` with validations, total recalculation, status management
- [x] Model: `ExpenseLineItem` with tax calculation, position ordering
- [x] Model: `ExpenseLineItemFile` join model
- [x] Model: `ExpenseFile` with `AssetFileUploadable`, hard delete + S3 cleanup
- [x] Model: `ExpenseReportSubmission` with snapshot creation/refresh
- [x] Model: `ExpenseReportReview` with status side effect
- [x] Concern: `AssetFileUploadable` S3 cleanup on destroy (before_destroy + after_destroy)
- [x] Sponsorship: added `has_one :expense_report` and `has_many :expense_files` associations
- [x] Factories and model specs (41 examples, all passing)

**4. Alba resources**
- [x] `ExpenseReportResource`, `ExpenseLineItemResource`, `ExpenseFileResource`, `ExpenseReportReviewResource` in `app/resources/`

**5. User-facing expense report API**
- [x] Routes: expense report, line items, submissions, files
- [x] Controller: `ExpenseReportsController` (create, show, update, calculate)
- [x] Controller: `ExpenseLineItemsController` (create, update, destroy)
- [x] Controller: `ExpenseReportSubmissionsController` (create, destroy)
- [x] Controller: `ExpenseFilesController` (create, update, show, destroy, initiate_update)
- [x] Request specs (15 examples, all passing; 449 total, 0 failures)

**6. Admin expense report API and views**
- [ ] Routes: admin expense report list, show/update, reviews, calculate
- [ ] Controller: `Admin::ExpenseReportsController` (index, show, update, calculate)
- [ ] Controller: `Admin::ExpenseReportReviewsController` (create)
- [ ] View: admin expense report list page (HAML)
- [ ] View: admin sponsorship show — expense report link

**7. Sponsor portal entry point and React mount**
- [ ] View: sponsor sponsorship show — expense report entry point section
- [ ] View: expense report show (HAML mount point for React, i18n data attributes)

**8. Frontend: 3-pane editor and API integration**
- [ ] React 3-pane expense report editor component (state management, API client)
- [ ] Left pane (line item list + unlinked files, iOS tableview style)
- [ ] Center pane (line item detail with @tanstack/react-form, file picker, tax mode selector)
- [ ] Right pane (file preview — img/iframe)
- [ ] i18n via data attributes
- [ ] Read-only mode for submitted/approved reports

**9. Frontend: file upload and drag-and-drop**
- [ ] File upload via AssetFileUploader pattern
- [ ] Drop zones (left pane for unlinked, center pane for linked)
- [ ] Line item reordering via @dnd-kit

**10. Frontend: admin review and rejection feedback**
- [ ] Admin review form below editor (approve/reject + comment)
- [ ] Sponsor view of rejection feedback (latest review comment)

**11. Slack notification**
- [ ] Job: Slack notification on submission (`:receipt:`, feed channel)

**12. Specs**
- [ ] Model specs (see Test Coverage section)
- [ ] Request specs (see Test Coverage section)

### Updates

Implementors MUST keep this section updated as they work.

- **2026-03-31 Phase 1**: Plan pricing — added `price` (decimal 12,2) and `price_booth` (decimal 12,2) columns to plans table. Added form fields in admin plans form and permitted params in controller. AR provides accessors so no model changes needed. Seeds not needed as defaults are 0 and values are editable via admin UI.
- **2026-03-31 Phase 2**: Dependencies — added alba gem, @tanstack/react-form, @dnd-kit/{core,sortable,utilities}. Added expense_report initializer with JCT tax rates.
- **2026-03-31 Phase 3**: Models and migrations — created 6 tables, 6 models, AssetFileUploadable S3 cleanup callbacks (before_destroy captures key, after_destroy deletes from S3), Sponsorship associations. Fixed 2 pre-existing tests broken by the new destroy callback (need S3 client stub). 41 new model specs + full suite (434 examples, 0 failures).
- **2026-03-31 Phase 4**: Alba resources — created 4 resource classes in `app/resources/` for JSON serialization.
- **2026-03-31 Phase 5**: User-facing API — 4 controllers (expense_reports, expense_line_items, expense_report_submissions, expense_files) with routes nested under sponsorship. 15 request specs passing.
