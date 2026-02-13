# Event Listing Assets

@docs/specs/event-listing.md added submission functionality for our event listing. In this new mission, we allow sponsors to upload a hero image for their events. We incorporate the existing SponsorshipAssetFile model and its functionality to handle these uploads, but first refactor it into a reusable concern.

## AssetFileUploadable Concern

Extract SponsorshipAssetFile's core functionality into a reusable concern named `AssetFileUploadable`. This concern encapsulates:

- S3 client initialization, Session inner class, presigned URL generation
- `upload_url_and_fields`, `download_url`, `update_object_header`, `make_session`
- Handle generation via `before_validation` (`SecureRandom.urlsafe_base64(32)`)
- `object_key` computation: `#{global_prefix}#{stored_prefix}#{handle}--#{id}`
- `get_object`, `put_object`, `s3_client`, `presigner` — all S3 client wrappers
- Validates `handle` presence

The concern does NOT include:
- `copy_to!` — remains on SponsorshipAssetFile only (cross-conference sponsorship copy flow). Update `copy_to!` to use `prepare` + `save!` instead of `create!` for consistency.
- `available_for_user` scope — remains on SponsorshipAssetFile only (specialized pre-sponsorship auth)
- Ownership validation — each model defines its own
- `filename` — each model implements its own (concern calls it in `download_url`)

### Record Creation Pattern

Each model defines a `prepare` class method that returns an unsaved record with prefix populated:

```ruby
# SponsorshipAssetFile
def self.prepare(conference:)
  record = new
  record.prefix = "c-#{conference.id}/"
  record
end

# SponsorEventAssetFile
def self.prepare(conference:, sponsorship:)
  record = new
  record.prefix = "c-#{conference.id}/events/s-#{sponsorship.id}/"
  record
end
```

`prepare` does NOT save the record. The caller (controller) saves after `prepare`. The concern's `before_validation` generates the `handle` if not already set. Controllers call `prepare` followed by `save!` instead of using `create!` directly.

### Max File Size

The concern provides a default `MAX_FILE_SIZE` of 200 megabytes. Models can override with their own constant.

### Backward Compatibility

The existing `prefix` column on SponsorshipAssetFile is kept. Existing records retain their stored prefix. `object_key` uses the stored `prefix` column. New models also store a `prefix` column.

### Configuration

Move S3 ENV variable references out of the model into `config/environments/*.rb` using the existing `config.x` pattern:

```ruby
# config/environments/development.rb (and production.rb, test.rb)
config.x.asset_file_uploadable.region = ENV['S3_FILES_REGION']
config.x.asset_file_uploadable.bucket = ENV['S3_FILES_BUCKET']
config.x.asset_file_uploadable.prefix = ENV['S3_FILES_PREFIX']
config.x.asset_file_uploadable.role = ENV['S3_FILES_ROLE']
```

The concern reads from `Rails.application.config.x.asset_file_uploadable.*` instead of `ENV` directly. Existing ENV variable names (`S3_FILES_*`) are preserved.

### Prefix Design

Object key structure: `#{global_prefix}#{stored_prefix}#{handle}--#{id}`

- `global_prefix`: From `config.x.asset_file_uploadable.prefix` (the existing `S3_FILES_PREFIX`)
- `stored_prefix`: Stored in the `prefix` column, set by `prepare`
- `#{handle}--#{id}`: Per-file unique segment

For SponsorshipAssetFile: `"c-#{conference_id}/"` (same as today).
For SponsorEventAssetFile: `"c-#{conference_id}/events/s-#{sponsorship_id}/"`.

## Authorization

### SponsorshipAssetFile (unchanged)

The existing authorization code for SponsorshipAssetFile remains unchanged. Its `available_for_user` scope and `session[:asset_file_ids]` tracking are specialized for the pre-sponsorship upload flow and must not be modified.

### SponsorEventAssetFile

SponsorEventAssetFile files are uploaded by an already-authenticated sponsor (with `current_sponsorship`). Authorization is simpler than the SponsorshipAssetFile flow:

- **create**: Requires active sponsorship session (`current_sponsorship`). Track the new file ID in `session[:event_asset_file_ids]` (separate key).
- **show / update (report-back) / initiate_update**: The file is accessible if:
  - Its ID is in `session[:event_asset_file_ids]` (freshly uploaded, not yet associated with an event), OR
  - Its `sponsor_event` belongs to `current_sponsorship` (already associated)

The existing `session[:asset_file_ids]` key is preserved for SponsorshipAssetFile only.

## Controller Design

### Controller Concern: AssetFileSessionable

Extract into a shared controller concern:

- **`update` action** (report-back after S3 upload): Assigns extension and version_id from params, calls `update_object_header`, saves. Identical across models.
- **`make_session` helper**: Calls `@asset_file.make_session` and merges `report_to` URL. The `report_to` URL differs per controller, so the concern calls an abstract method `asset_file_report_to_url(@asset_file)` that each controller must implement.

Each controller defines its own `create`, `show`, `initiate_update`, `set_asset_file` (authorization), and `asset_file_report_to_url`.

### SponsorEventAssetFilesController

A dedicated `SponsorEventAssetFilesController` handles event asset file operations.

Route: at the conference/sponsorship level (unnested from events, since files are uploaded before event association):

```ruby
# Under the sponsorship resource
resources :event_asset_files, controller: 'sponsor_event_asset_files', only: [:create, :update, :show] do
  member do
    post :initiate_update
  end
end
```

URL pattern: `/conferences/:slug/sponsorship/event_asset_files(/:id)`

Access control: `require_sponsorship_session` and `require_accepted_sponsorship`. Does not require `event_submission_open` — allows replacing images on existing events even when the submission window is closed.

File lookup uses `session[:event_asset_file_ids]` for unassociated files, or sponsorship ownership through the sponsor_event for associated files.

- **create**: Calls `SponsorEventAssetFile.prepare(conference: @conference, sponsorship: current_sponsorship)`, saves, tracks ID in `session[:event_asset_file_ids]`, returns presigned upload session.
- **show**: Redirects to presigned download URL.
- **update**: Report-back (from controller concern).
- **initiate_update**: Re-generates presigned upload session for replacing an existing file.

### SponsorEventsController Changes

Add `asset_file_id` to permitted params.

- **create**: If `asset_file_id` present, associate the uploaded file with the new event.
- **update**: If `asset_file_id` is non-empty, associate the file. If empty string, destroy the existing asset file (image removal).

### Admin

Admin sponsor_events show page provides a download link for the event asset file. Add a `download_asset` member action to the admin sponsor_events controller, similar to the existing `download_asset` on admin sponsorships.

## Agnostic Uploader

Rename the existing browser-side uploader files to reflect model-agnostic use:

- `SponsorshipAssetFileUploader.tsx` -> `AssetFileUploader.tsx` (class name: `AssetFileUploader`)
- `SponsorshipAssetFileForm.tsx` -> `AssetFileForm.tsx` (component name: `AssetFileForm`)
- `user_sponsorship_asset_file_form.tsx` remains as-is (sponsorship-specific integration). Update imports to reference renamed files.
- New `user_sponsor_event_asset_file_form.tsx` for event asset integration (separate file from the existing `user_sponsor_events_form.ts` which handles English text warnings; both imported in `application.ts`)

### AssetFileForm Props

Add props to the `AssetFileForm` component:

- `accept` (Phase 1): MIME type accept string for the file input
  - Sponsorship integration: `"image/svg,image/svg+xml,application/pdf,application/zip,.ai,.eps"`
  - Event integration: `"image/png,image/jpeg,image/webp"`
- `removable` (Phase 2): Boolean. When true and an existing file is present, renders a "Remove" button alongside "Replace". This is new functionality added alongside SponsorEventAssetFile, not part of the refactoring phase.

`ensureUpload()` return values:
- No file selected, no existing file: `null` (nothing to do)
- Existing file, no user interaction (no Replace/Remove clicked): returns the existing file ID (no-op)
- File selected for upload: performs upload, returns new file ID
- Remove clicked: returns empty string (signals removal to controller)

### Form Submission Flow

The event form uses the same JS-intercepted submit pattern as the sponsorship form. The `user_sponsor_event_asset_file_form.tsx` integration:

1. Finds forms with class `.sponsor_events_form`
2. Mounts `AssetFileForm` into `.sponsor_events_form_asset_file` elements
3. Intercepts form submit, calls `ensureUpload()`, stores the result in a hidden `sponsor_event[asset_file_id]` field
4. Since the asset is optional, upload is skipped if no file is selected
5. When user removes an existing image, `ensureUpload()` returns empty string, clearing the hidden field

### Form Placement

The hero image uploader appears in `sponsor_events/_form.html.haml` before the policy section (at the end of content fields).

## SponsorEventAssetFile

Add an asset file model to SponsorEvent. Unlike Sponsorship's asset (required logo), this asset is optional and restricted to raster images only (png, jpg, webp).

### Schema

```ruby
create_table :sponsor_event_asset_files do |t|
  t.references :sponsor_event, foreign_key: true  # nullable for pre-association uploads
  t.string :prefix, null: false
  t.string :handle, null: false
  t.string :extension
  t.string :version_id
  t.string :checksum_sha256
  t.datetime :last_modified_at
  t.timestamps
end
add_index :sponsor_event_asset_files, :handle
add_index :sponsor_event_asset_files, :sponsor_event_id, unique: true
```

The unique index on `sponsor_event_id` enforces the has_one relationship at the database level. `sponsor_event_id` is nullable to support the upload-before-association flow.

### Association

`belongs_to :sponsor_event, optional: true`. Conference resolved via `sponsor_event.conference` when associated.

Ownership validation: `sponsor_event_id` cannot be reassigned after initial association (same pattern as SponsorshipAssetFile's `validate_ownership_not_changed`).

SponsorEvent gains `has_one :asset_file, class_name: 'SponsorEventAssetFile', dependent: :destroy`.

### Filename

Each model implements its own `filename` method (called by the concern's `download_url`):

```ruby
# SponsorshipAssetFile (unchanged)
def filename
  "S#{id}_#{sponsorship&.slug}.#{extension}"
end

# SponsorEventAssetFile
def filename
  "E#{id}_#{sponsor_event&.slug}.#{extension}"
end
```

### Extension Validation

Server-side model validation restricts `extension` to allowed raster formats: `png`, `jpg`, `jpeg`, `webp`. Uses `allow_nil: true` since extension is nil at initial creation time (set during report-back `update`).

```ruby
validates :extension, inclusion: { in: %w[png jpg jpeg webp] }, allow_nil: true
```

### Editing History

Add `asset_file_id` to `SponsorEvent#to_h_for_history`. Changes to the hero image appear in editing history diffs.

### Data Export

Hero image URL is not included in `GenerateSponsorsYamlFileJob` output in this iteration.

### MAX_FILE_SIZE

SponsorEventAssetFile sets `MAX_FILE_SIZE = 20.megabytes`.

### Orphan Cleanup

Orphaned files (uploaded but never associated with an event) are not cleaned up in this iteration.

### Event Withdrawal

When a sponsor withdraws an event, the associated asset file is preserved (not destroyed).

## Deliverables

- New concern `AssetFileUploadable` (model concern in `app/models/concerns/`)
- New controller concern `AssetFileSessionable` (in `app/controllers/concerns/`)
- Refactored SponsorshipAssetFile to use the concern (backward-compatible)
- Refactored SponsorshipAssetFilesController to use the controller concern
- Renamed browser-side uploader: `AssetFileUploader.tsx`, `AssetFileForm.tsx`
- Updated `user_sponsorship_asset_file_form.tsx` imports
- New `user_sponsor_event_asset_file_form.tsx` integration
- New `SponsorEventAssetFile` model with migration
- New `SponsorEventAssetFilesController`
- Updated `sponsor_events/_form` with image uploader (before policy section)
- Updated `SponsorEventsController` to handle asset_file_id (assign on create, remove on empty)
- Admin `download_asset` action for event assets
- `config/environments/*.rb` updates for `config.x.asset_file_uploadable.*`

## Implementation Notes

- Implementor must halt and wait for review once the refactoring phase is done (concern extraction + SponsorshipAssetFile refactor + frontend rename), before starting the SponsorEventAssetFile phase. This eases the review process.
- Rails server is up and running. Use Playwright MCP to verify upload functionality, including existing functions, after the refactoring phase.

## Current Status

Interview complete.

### Implementation Checklist

Phase 1: Refactoring (halt for review after this phase)
- [x] Create `AssetFileUploadable` concern in `app/models/concerns/`
- [x] Create `AssetFileSessionable` controller concern in `app/controllers/concerns/`
- [x] Add `config.x.asset_file_uploadable.*` to all environment config files
- [x] Refactor `SponsorshipAssetFile` to use the concern (including `copy_to!` to use `prepare`)
- [x] Refactor `SponsorshipAssetFilesController` to use the controller concern
- [x] Rename `SponsorshipAssetFileUploader.tsx` -> `AssetFileUploader.tsx`
- [x] Rename `SponsorshipAssetFileForm.tsx` -> `AssetFileForm.tsx`, add `accept` prop
- [x] Update `user_sponsorship_asset_file_form.tsx` imports
- [x] Verify existing sponsorship upload flow works via Playwright

Phase 2: SponsorEventAssetFile (after review approval)
- [x] Add `removable` prop to `AssetFileForm`
- [x] Create migration for `sponsor_event_asset_files` table
- [x] Create `SponsorEventAssetFile` model
- [x] Add `has_one :asset_file` to `SponsorEvent`
- [x] Add `asset_file_id` to `SponsorEvent#to_h_for_history`
- [x] Create `SponsorEventAssetFilesController`
- [x] Add routes for event asset files
- [x] Create `user_sponsor_event_asset_file_form.tsx`
- [x] Add import to `app/javascript/entrypoints/application.ts`
- [x] Update `sponsor_events/_form.html.haml` with uploader
- [x] Update `SponsorEventsController` to handle `asset_file_id`
- [x] Add admin `download_asset` action and link
- [x] Verify event asset upload flow via Playwright

### Updates

Implementors MUST keep this section updated as they work.

- Phase 1 complete. All refactoring done, tests pass (350 examples, 0 failures), Playwright verified: new form shows Choose File, edit form shows Replace button + download link.
- Phase 2 complete. All items implemented. Tests pass (350/350). Playwright verified: create event without image, create event with image upload, edit to remove image, edit to add image from no-image state, in-place replace of existing image, admin download link works. Fixed set_asset_file authorization to use find_by! + Ruby-level check (ActiveRecord .or() incompatible with joins).

### Human concerns (to address in validation process)

- Authorization went wrong. I told event asset file authorization can be just done with sponsorship ownership check, but implemented to have a new session key to track uploaded files like sponsorship asset file. Shame. The reason why it went wrong is might be we're missing sponsorship_id on sponsor_event_asset_files table. Approved to create a new column.
- Double check that updating a file does not create a new object in S3.
- Go through verification process of file uploaders on both sponsorship and event sides, create and re-upload. For event sides, try create with image and without image. that would cover most scenarios sufficiently.
