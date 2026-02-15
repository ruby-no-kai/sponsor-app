# root-page

The root page (`GET /`, `root#index`) currently redirects to an open sponsorship application form. This causes three problems:

1. **Unnecessary SQL queries**: Bot traffic triggers database queries on every visit.
2. **Empty page**: When no sponsorship application is open, users see a blank page.
3. **Hidden login link**: Returning sponsors struggle to find the login link (only in the navbar).

## Solution overview

1. Make the root page cacheable via CloudFront (Terraform + Rails changes)
2. Migrate locale preference from session to a dedicated cookie (app-wide)
3. Render a proper root page for unauthenticated users with sponsorship and login links

Scope is limited to the root page (`GET /`). The `/conferences` page remains unchanged.

## 1. Cacheable root page

### CloudFront layer (`tf/cloudfront.tf`)

Add an `ordered_cache_behavior` for path pattern `/` before the default behavior:
- Forwards only the locale cookie (`__Host-rk-sponsorapp2-hl`); does **not** forward session cookies
- Forwards only the `CloudFront-Viewer-Country` header (for locale auto-detection); other headers (`x-csrf-token`, `User-Agent`, `Origin`) are not forwarded to maximize cache hit rate
- Forwards query strings (for `?hl=` locale switching)
- `allowed_methods`: `GET`, `HEAD`
- `compress`: `true`
- `viewer_protocol_policy`: `redirect-to-https`
- TTL: `min_ttl=0`, `default_ttl=0`, `max_ttl=3600`

Also update the existing default cache behavior:
- Add `__Host-rk-sponsorapp2-hl` to the whitelisted cookies
- Remove the legacy `sponsorapp2` cookie from the whitelist

### Rails layer (`app/controllers/root_controller.rb`)

In `RootController#index`, check both `current_available_sponsorships` and `current_staff` to detect a logged-in user:

**Logged in** (either helper returns truthy):
- Redirect to `/conferences` (preserving current behavior)
- No caching changes; session functions normally

**Not logged in** (cacheable path):
- Set `request.session_options[:skip] = true` to suppress session `Set-Cookie` header
- Set instance variable (e.g., `@cacheable = true`) for use in the layout
- Set `Cache-Control: public, s-maxage=3600, max-age=0` so CloudFront caches for 1 hour but browsers always revalidate
- Query `Conference.application_open.publicly_visible` and render `root/index`

### Layout changes (`app/views/layouts/application.html.haml`)

Conditionally omit `csrf_meta_tags` when `@cacheable` is set. All other layout elements (navbar, flash messages, etc.) remain unchanged. On the cached path, session-dependent navbar elements (`current_available_sponsorships`, `current_staff`) are nil, so the navbar naturally shows the unauthenticated state (brand, "All Conferences", language selector, "Log in" link).

### Security

Dropping session dependency on the cached path is critical for security. Tests must validate:
- The cached response body contains no CSRF meta tag
- The cached response contains no session `Set-Cookie` header
- Reading session data is harmless (returns nil); only writing/emitting the session cookie must be prevented

## 2. Locale storage migration (app-wide)

Migrate locale preference from `session[:hl]` to a dedicated cookie across the entire application.

### Cookie configuration

Cookie name configured via `config.x.locale_cookie_name` in each environment file:
- **All environments**: `__Host-rk-sponsorapp2-hl`

`Secure; Path=/; httponly=false`. localhost is a trustworthy origin so `__Host-` works on all environments.

Cookie expiration: **1 year**.

### Changes to `ApplicationController#set_locale`

Priority order for locale detection:
1. `params[:hl]` — if present and valid, write to locale cookie
2. Locale cookie — read from `cookies[config.x.locale_cookie_name]`
3. `session[:hl]` — fallback for backward compatibility; migrates value to cookie
4. `CloudFront-Viewer-Country` header — if `jp`, set locale to `:ja` and write to cookie

When `params[:hl]` is present but not a valid locale, delete the locale cookie.

On the cached root page, `?hl=` sets the locale cookie via `Set-Cookie` header. CloudFront caches the response including the `Set-Cookie`; this is acceptable because the same query string always produces the same cookie value (e.g., `/?hl=ja` always sets cookie to `ja`).

## 3. Root page content

### View template (`app/views/root/index.html.haml`)

Uses the existing `application` layout (with conditional CSRF omission). All text localized via i18n (en.yml and ja.yml) under a `root.index` namespace.

### Single open conference

Two horizontally-placed sections (e.g., Bootstrap grid with `.col-md-6`):

**Left**: "Become a sponsor" heading, followed by a "New sponsorship application" button linking to `new_user_conference_sponsorship_path(conference)`.

**Right**: "Already a sponsor?" heading, followed by a "Login" button linking to `new_user_session_path`.

### Multiple open conferences

A card containing a `<ul>` list of `<a>` links, each linking to `new_user_conference_sponsorship_path(conference)` with the conference name as link text. Plus the "Already a sponsor?" section with the login button.

### No open applications

A message: "There are currently no open sponsorship applications for {org_name}." (interpolating `Rails.application.config.x.org_name`). Plus the "Already a sponsor?" section with the login button.

## Deliverables

### Rails

- `app/controllers/root_controller.rb` — rewrite with cacheable/redirect logic
- `app/views/root/index.html.haml` — new template for all three content states
- `app/views/layouts/application.html.haml` — conditional CSRF meta tag omission
- `app/controllers/application_controller.rb` — migrate `set_locale` to cookie-based
- `config/environments/production.rb` — add `config.x.locale_cookie_name`
- `config/environments/development.rb` — add `config.x.locale_cookie_name`
- `config/environments/test.rb` — add `config.x.locale_cookie_name`
- `config/locales/en.yml` — add `root.index.*` keys
- `config/locales/ja.yml` — add `root.index.*` keys

### Terraform

- `tf/cloudfront.tf` — add `/` ordered cache behavior; update default behavior cookie whitelist (add locale cookie, remove `sponsorapp2`)

### Tests

- `spec/requests/root_spec.rb` — full request specs

## Test plan (`spec/requests/root_spec.rb`)

### Security/caching (unauthenticated)

- Response body does not contain `<meta name="csrf-token"`
- Response does not include a `Set-Cookie` header for the session cookie
- Response includes `Cache-Control` header with `s-maxage=3600`

### Content (unauthenticated)

- **Single open conference**: renders link to `new_user_conference_sponsorship_path` and link to `new_user_session_path`
- **Multiple open conferences**: renders link for each conference and link to `new_user_session_path`
- **No open conferences**: renders message with org name and link to `new_user_session_path`

### Logged-in behavior

- With sponsorship session: redirects to `/conferences`
- With staff session: redirects to `/conferences`

### Locale

- `GET /?hl=ja` sets locale cookie and renders page in Japanese
- Locale cookie is read and applied on subsequent requests

## Current Status

Interview complete.

### Implementation checklist

Locale storage migration is a standalone refactoring. Commit it separately before the root page changes to ease review.

**Commit 1: Locale storage migration (refactoring)**
- [x] Add `config.x.locale_cookie_name` to production, development, and test environment files
- [x] Migrate `ApplicationController#set_locale` from session to cookie

**Commit 2: Cacheable root page**
- [ ] Rewrite `RootController#index` with logged-in redirect and cacheable rendering
- [ ] Conditional CSRF meta tag omission in `app/views/layouts/application.html.haml`
- [ ] Create `app/views/root/index.html.haml` with all three content states
- [ ] Add i18n keys to `config/locales/en.yml` and `config/locales/ja.yml`
- [ ] Add ordered cache behavior for `/` in `tf/cloudfront.tf`
- [ ] Update default cache behavior cookies in `tf/cloudfront.tf` (add locale, remove `sponsorapp2`)
- [ ] Write `spec/requests/root_spec.rb` with security, content, logged-in, and locale tests

### Updates

Implementors MUST keep this section updated as they work.
