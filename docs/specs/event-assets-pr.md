# events-assets-pr

In //docs/specs/events-assets.md, SponsorEvent gained SponsorEventAssetFile model to accept hero images for public event listing.

We feed sponsorships and events data into a GitHub repository via GenerateSponsorsYamlFileJob, triggered when a sponsorship or event is updated or created. However, we currently miss automatic feed for event asset files.

This spec covers a new job to push event asset files (hero images) into the same GitHub repository as converted webp images via pull requests.

## Phase 1: GithubInstallation extraction

### GithubInstallation model

Extract GitHub App authentication from GenerateSponsorsYamlFileJob into a new model `GithubInstallation` at `app/models/github_installation.rb`.

Constructor: `GithubInstallation.new(repo_name, branch: nil)`. Accepts a GitHub repo name string (e.g. `"ruby-no-kai/rubykaigi"`) and an optional branch name.

```ruby
gi = GithubInstallation.new("owner/repo", branch: "main")
gi.octokit        #=> Octokit::Client authenticated for the repo's GitHub App installation
gi.base_branch    #=> configured branch, or fetched default branch if nil
gi.default_branch #=> always fetched from GitHub API
```

Methods to extract from GenerateSponsorsYamlFileJob:
- **Authentication:** `octokit`, `github_installation_token`, `app_octokit`, `github_jwt`
- **Branch helpers:** `base_branch` (returns configured branch or `default_branch`), `default_branch` (fetches from GitHub API via `octokit.repository(repo_name)[:default_branch]`)
- **Constant:** `GITHUB_MEDIA_TYPE`

These are the methods common to both GenerateSponsorsYamlFileJob and the new PushEventAssetFileJob.

### GenerateSponsorsYamlFileJob refactoring

Update GenerateSponsorsYamlFileJob to use GithubInstallation internally:
- Initialize a `GithubInstallation` instance with `repo.name` and `branch: repo.branch`.
- Replace `octokit`, `github_installation_token`, `app_octokit`, `github_jwt`, `base_branch`, `default_branch` methods with delegation to the GithubInstallation instance.
- The `push_to_github`, `data`, `events_data`, `yaml_data`, `json_data`, and `repo` methods remain on the job.
- Update the `self.get_octokit` debugging class method to use GithubInstallation.

Halt for review after Phase 1. Verify GenerateSponsorsYamlFileJob still works correctly after the refactoring.

## Phase 2: PushEventAssetFileJob

### Editing history enhancement

Add `asset_file_checksum_sha256` to `SponsorEvent#to_h_for_history`:

```ruby
"asset_file_checksum_sha256" => asset_file&.checksum_sha256,
```

This enables detecting in-place image replacements where `asset_file_id` stays the same but the S3 content changes (via `initiate_update` re-upload flow).

### Database migration

Add `github_repo_images_path` column to `conferences`, nullable string. This is a path prefix within the same repository specified by `github_repo` (e.g. `"images"`). It is NOT a separate repo specification.

### Admin UI

Add a `github_repo_images_path` text field to the admin conference form (`app/views/admin/conferences/_form.html.haml`), placed after the existing `github_repo` field. Add `:github_repo_images_path` to `conference_params` in `Admin::ConferencesController`.

### Dockerfile

Add `libvips-tools` to the `apt-get install` line in the runtime stage of `Dockerfile`:

```dockerfile
apt-get install --no-install-recommends -y libpq5 libyaml-dev libvips-tools
```

### Job trigger (ProcessSponsorEventEditJob changes)

Add logic to `ProcessSponsorEventEditJob` to trigger `PushEventAssetFileJob.perform_later(edit)` under these conditions:

1. **Asset file content changed:** Event is `accepted` AND has an `asset_file` AND the editing history diff includes a change to `asset_file_id` or `asset_file_checksum_sha256`.
2. **Status changed to accepted:** The diff shows status changed to `accepted` AND event has an `asset_file`.

Check the diff using the same pattern as `status_changed_in_edit?`: inspect `change[1]` for the field name.

Do NOT trigger when asset file is removed (`asset_file_id` changes to nil). Do NOT trigger for non-accepted events.

### PushEventAssetFileJob

Create `app/jobs/push_event_asset_file_job.rb`. Add `require 'open3'` at the top.

Receives a `SponsorEventEditingHistory` record as its parameter. Dispatch via `perform_later` (async, queued to SQS).

#### Guard conditions

Return immediately (no error) when any of:
- Conference has blank `github_repo_images_path`
- Conference has no `github_repo` configured
- Event's status is not `accepted`
- Event has no `asset_file`

#### Image conversion

1. Download the original image from S3 via `asset_file.get_object`.
2. Create a temp directory at `Rails.root.join('tmp', "PushEventAssetFileJob-#{job_id}-#{asset_file.id}")`.
3. Write the downloaded content to `input.#{asset_file.extension}` inside the temp directory.
4. Run vipsthumbnail via `Open3.capture3`:

```ruby
Open3.capture3(
  { 'VIPS_BLOCK_UNTRUSTED' => '1' },
  'vipsthumbnail', input_path.to_s,
  '-s', '800',
  '-o', output_path.to_s + '[Q=72,preset=drawing,smart_subsample=true,effort=6,strip=true]'
)
```

The output filename is `output.webp` in the temp directory. vipsthumbnail determines format from the `.webp` extension; the `[...]` suffix contains save options, not part of the filename.

5. If vipsthumbnail exits with non-zero status, raise an error (Shoryuken retries per its retry policy).
6. Read the converted webp output via `File.binread`.
7. Clean up the temp directory on successful completion (`FileUtils.rm_rf`). On failure, leave it for debugging.

#### GitHub push

URL helpers for admin URL generation are inherited from `ApplicationJob` (which includes `Rails.application.routes.url_helpers` and defines `default_url_options` using `config.x.public_url_host`).

1. Initialize `GithubInstallation.new(repo.name, branch: repo.branch)` where `repo = conference.github_repo`.
2. Strip trailing slashes from `github_repo_images_path` when constructing the file path.
3. Branch name: `"sponsor-app/event-asset/#{sponsorship.id}-#{event.id}/#{editing_history.id}"`
4. Delete existing branch if present (rescue `Octokit::UnprocessableEntity`).
5. Create branch ref from `gi.base_branch`.
6. Get existing blob SHA at target path (rescue `Octokit::NotFound` → nil).
7. Commit via `octokit.update_contents`:
   - Path: `"#{images_path}/events/#{sponsorship.id}-#{event.id}.webp"` (images_path is `github_repo_images_path` with trailing slashes stripped)
   - Message: same as PR title.
   - Content: the converted webp binary (from `File.binread`).
8. Create pull request:
   - Title: `"Event asset: #{sponsorship.name} [#{event.id}@#{editing_history.id}]"`
   - Body (Markdown):

```markdown
## Event Asset

- **Event:** #{event.title}
- **Sponsor:** #{sponsorship.name}
- **Admin:** #{conference_sponsor_event_url(conference, event)}
```

Admin URL host is resolved via `ApplicationJob#default_url_options` (uses `config.x.public_url_host` from `DEFAULT_URL_HOST` env var).

No locking needed — each push uses a unique branch name (includes editing history ID), so concurrent pushes for the same event don't conflict.

Each asset file change creates a new PR. No deduplication — reviewers merge or close as needed.

## Security considerations

- Call libvips via `Open3.capture3` with array form. Do not use Shellwords or string interpolation for command construction.
- Set `VIPS_BLOCK_UNTRUSTED=1` environment variable when calling vips commands.
- Temp file paths are constructed from trusted values (`job_id`, `asset_file.id`) — no user-controlled path components.

## Test expectations

All external services (S3, GitHub API, vipsthumbnail) must be mocked in tests.

### GithubInstallation

- Creates JWT with correct payload (`iss`, `iat`, `exp`).
- Finds repository installation and creates access token.
- Returns an authenticated Octokit client.
- `base_branch` returns the configured branch when present.
- `base_branch` fetches default branch from GitHub when configured branch is nil.

### GenerateSponsorsYamlFileJob (after refactoring)

- Existing tests continue to pass — behavior is unchanged.

### SponsorEvent#to_h_for_history

- Includes `asset_file_checksum_sha256` with the asset file's checksum value.
- Returns nil for `asset_file_checksum_sha256` when no asset file is associated.

### ProcessSponsorEventEditJob trigger logic

- Triggers `PushEventAssetFileJob` when `asset_file_id` changes in diff (new file associated).
- Triggers when `asset_file_checksum_sha256` changes in diff (in-place replacement).
- Triggers when status changes to `accepted` and event has an `asset_file`.
- Does NOT trigger when `asset_file_id` changes to nil (removal).
- Does NOT trigger for non-accepted events with asset file changes.

### PushEventAssetFileJob

- Returns early for each guard condition (blank `github_repo_images_path`, no `github_repo`, non-accepted event, no asset file).
- Downloads image from S3 via `asset_file.get_object`.
- Invokes vipsthumbnail with correct arguments including `VIPS_BLOCK_UNTRUSTED=1` env var.
- Creates GitHub branch, commits webp file at correct path, creates PR.
- PR title and body match expected format.
- Raises on vipsthumbnail non-zero exit.
- Cleans up temp directory on success.

## Deliverables

### Phase 1 (halt for review)
- `app/models/github_installation.rb`
- Updated `app/jobs/generate_sponsors_yaml_file_job.rb` (use GithubInstallation)
- `spec/models/github_installation_spec.rb`

### Phase 2
- Migration: add `github_repo_images_path` to conferences
- `app/jobs/push_event_asset_file_job.rb`
- Updated `app/jobs/process_sponsor_event_edit_job.rb` (trigger logic)
- Updated `app/models/sponsor_event.rb` (`to_h_for_history` enhancement)
- Updated `app/views/admin/conferences/_form.html.haml` (new field)
- Updated `app/controllers/admin/conferences_controller.rb` (permit param)
- Updated `Dockerfile` (add libvips-tools)
- `spec/jobs/push_event_asset_file_job_spec.rb`
- `spec/jobs/process_sponsor_event_edit_job_spec.rb` (new file, trigger tests)

## Current Status

Implementation complete.

### Implementation Checklist

Phase 1: GithubInstallation extraction
- [x] Create `app/models/github_installation.rb`
- [x] Refactor `app/jobs/generate_sponsors_yaml_file_job.rb` to use GithubInstallation
- [x] Update `self.get_octokit` debugging method
- [x] Create `spec/models/github_installation_spec.rb`
- [x] Verify existing `generate_sponsors_yaml_file_job_events_spec.rb` passes

Phase 2: PushEventAssetFileJob
- [x] Add `asset_file_checksum_sha256` and `asset_file_version_id` to `SponsorEvent#to_h_for_history`
- [x] Create migration: add `github_repo_images_path` to conferences
- [x] Add `github_repo_images_path` to admin conference form and permitted params
- [x] Add libvips to Dockerfile runtime stage
- [x] Create `app/jobs/push_event_asset_file_job.rb`
  - [x] Accepts SponsorEventEditingHistory, SponsorEvent, or SponsorEventAssetFile
  - [x] Uses `get_object(response_target:)` for streaming S3 download
- [x] Update `app/jobs/process_sponsor_event_edit_job.rb` with trigger logic
- [x] Update `app/models/concerns/asset_file_uploadable.rb` (`get_object` accepts kwargs)
- [x] Create `spec/jobs/push_event_asset_file_job_spec.rb`
- [x] Create `spec/jobs/process_sponsor_event_edit_job_spec.rb`
- [x] Verify all tests pass (381 examples, 0 failures)

### Updates

Implementors MUST keep this section updated as they work.

- 2026-02-14: Spec interview complete. All design decisions resolved across 7 interview rounds.
- 2026-02-14: Phase 1 implemented. GithubInstallation extracted, GenerateSponsorsYamlFileJob refactored, all 355 tests pass.
- 2026-02-14: Phase 2 implemented. PushEventAssetFileJob, trigger logic, migration, admin UI, specs. 381 tests pass. Dockerfile in progress separately.
- 2026-02-14: Phase 2 implemented. All code and specs complete; 377 examples pass. Dockerfile `libvips-tools` change deferred.
- 2026-02-14: Dockerfile complete. Built minimal libvips 8.18.0 from source (multi-stage, JPEG/PNG/WebP only) instead of `libvips-tools` apt package to avoid pulling dozens of unnecessary transitive dependencies. Installed to `/opt/libvips` with symlink in `/usr/local/bin`. All deliverables done.
