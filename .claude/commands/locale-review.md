---
description: Generate or apply a locale review file for comparing EN/JA translations
argument-hint: <generate|apply> <scope>
allowed-tools: [Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(rails runner:*), Bash(rspec:*)]
---

# Locale Review Command

Arguments: $ARGUMENTS

This command supports a two-phase workflow for reviewing locale strings added or modified for a feature.

## Phase: `generate <scope>`

The `<scope>` argument is arbitrary text describing what to review. It is typically a path to a spec file (e.g., `docs/specs/event-listing.md`), but can also be a feature name, a model name, a file path glob, or any descriptive text.

Generate a side-by-side EN/JA locale review file at `tmp/<feature-name>-locale-review.md` (derive `<feature-name>` from the scope, e.g., the spec file's basename without extension).

### Determining Scope

1. If the scope points to a file (e.g., a spec file), read it to understand what models, controllers, and views are involved
2. Use `git diff HEAD` and/or `git log --oneline` + `git show` to identify which locale keys and view files were added or modified
3. Combine information from both the scope description and git diff to determine the full set of relevant locale keys
4. If the scope is still ambiguous (e.g., changes span many unrelated namespaces, or it's unclear which keys belong to the feature), use AskUserQuestion to ask the user to clarify

### Steps

1. Read `config/locales/en.yml` and `config/locales/ja.yml`
2. Identify all locale keys related to the feature from the scope and git diff. Look for:
   - Model attribute keys (e.g., `activerecord.attributes.<model>`)
   - Controller/view keys (e.g., `<feature_name>.new`, `<feature_name>.edit`, `<feature_name>.show`, `<feature_name>.form`)
   - Shared keys referenced in views (e.g., `views.<feature_name>`)
   - Any other keys that appear in the feature's views and controllers
3. Also scan view files (`app/views/` related to the feature) for `t(` calls to find all referenced locale keys, including keys from shared namespaces
4. Generate `tmp/<feature-name>-locale-review.md` with all found strings grouped by namespace

### Review File Format

```markdown
# <Feature Name> Locale Review

## `<namespace>`

- `<key>`
  - English: <value>
  - Japanese: <value>
```

Use `<!-- TODO: ... -->` comments to flag potential issues like:
- Duplicate keys across namespaces that could be consolidated
- Keys that could reuse model attribute names via `human_attribute_name`
- Inconsistent terminology between EN and JA

### After Generation

Tell the user:
- The review file has been generated at `tmp/<feature-name>-locale-review.md`
- They should edit the file to adjust translations, add/remove keys, and resolve TODOs
- When done, run `/locale-review apply <feature-name>` to apply changes

## Phase: `apply <feature-name>`

`<feature-name>` here corresponds to the review file basename (as derived during `generate`).

Read the reviewed file at `tmp/<feature-name>-locale-review.md` and apply all changes.

### Steps

1. Read the reviewed `tmp/<feature-name>-locale-review.md`
2. Run `git diff` on the review file to see what the user changed. Use this diff to focus on modified, added, or removed keys rather than re-diffing the entire file against yml sources.
3. Compare the review file against current `config/locales/en.yml` and `config/locales/ja.yml` for the changed keys
4. Detect newly added keys (keys present in the review file but not yet in the yml files or not yet referenced in any view). For each new key:
   - Try to infer the intended usage from the key name, namespace, and surrounding view code (e.g., a `_help` suffix likely means a `%small.form-text` hint below a form field)
   - Use AskUserQuestion to confirm the intended usage, presenting your best guess as the first option to keep the process quick. For example: "Key `sponsor_events.form.description_help` appears to be a help text for the description field. Where should it be added?"
   - Only proceed with adding the key to views after the user confirms
5. For each difference found:
   - Update the locale value in the appropriate yml file
   - If keys were removed from the review file (e.g., marked as duplicate), remove them from yml files
6. Process TODO comments in the review file:
   - If a TODO says to reuse model attributes (e.g., `human_attribute_name`), update the corresponding view to use `ModelName.human_attribute_name(:attr)` instead of `t('.key')`, then remove the duplicate locale key
   - If a TODO says to consolidate duplicate keys, update views to reference the canonical key location, then remove duplicates
7. After applying locale changes, update any view files that need to reference changed or consolidated keys
8. Verify changes:
   - Run `rails runner` to confirm locale files load correctly
   - Run relevant specs if they exist

### Important

- Only modify locale keys that appear in the review file. Do not touch unrelated keys.
- When consolidating duplicate keys, always update the views first to point to the canonical location, then remove the duplicate.
- Preserve the YAML structure and indentation of the locale files.
- Enter plan mode before applying changes to confirm the plan with the user.
