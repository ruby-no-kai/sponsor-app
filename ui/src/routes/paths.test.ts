import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { isSpaPathname, matchSpaPath } from "./paths.ts";

const BASE = "http://sponsor-app.localhost:1355/admin";

describe("isSpaPathname", () => {
  it("matches whole SPA paths only", () => {
    assert.ok(isSpaPathname("/admin"));
    assert.ok(isSpaPathname("/admin/conferences"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048"));
    assert.ok(!isSpaPathname("/admin/session/new"));
    assert.ok(!isSpaPathname("/"));
  });

  it("matches the conference pages HAML has at the same paths", () => {
    assert.ok(isSpaPathname("/admin/conferences/new"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/edit"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/attendees_keeper"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/table_view"));
  });

  it("leaves the conference exports to Rails", () => {
    assert.ok(!isSpaPathname("/admin/conferences/rubykaigi2048/sponsors_yml"));
    assert.ok(!isSpaPathname("/admin/conferences/rubykaigi2048/sponsors_json"));
    assert.ok(!isSpaPathname("/admin/conferences/rubykaigi2048/asset_urls"));
  });

  it("matches the form description pages HAML has at the same paths", () => {
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/form_descriptions/new"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/form_descriptions/ja"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/form_descriptions/ja/edit"));
    assert.ok(!isSpaPathname("/admin/conferences/rubykaigi2048/form_descriptions"));
  });

  it("matches the plan pages HAML has at the same paths", () => {
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/plans"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/plans/new"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/plans/12/edit"));
    assert.ok(!isSpaPathname("/admin/conferences/rubykaigi2048/plans/12"));
  });

  it("matches the sponsorship pages but leaves downloads and note edits to Rails", () => {
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/sponsorships/42"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/sponsorships/42/edit"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/sponsorships/42/editing_history"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/sponsorships/42/staff_notes"));
    assert.ok(!isSpaPathname("/admin/conferences/rubykaigi2048/sponsorships/42/download_asset"));
    assert.ok(!isSpaPathname("/admin/conferences/rubykaigi2048/sponsorships/42/expense_report"));
    assert.ok(
      !isSpaPathname("/admin/conferences/rubykaigi2048/sponsorships/42/staff_notes/7/edit"),
    );
  });

  it("matches the organization pages HAML has at the same paths, domains with dots included", () => {
    assert.ok(isSpaPathname("/admin/organizations"));
    assert.ok(isSpaPathname("/admin/organizations/new"));
    assert.ok(isSpaPathname("/admin/organizations/contoso.example.co.invalid"));
    assert.ok(isSpaPathname("/admin/organizations/contoso.example.co.invalid/edit"));
    assert.ok(!isSpaPathname("/admin/organizations/contoso.example.co.invalid/sponsorships"));
  });

  it("matches the booth assignment page", () => {
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048/booth_assignment"));
  });
});

describe("matchSpaPath", () => {
  it("resolves relative hrefs and ignores the query and fragment", () => {
    assert.ok(matchSpaPath("/admin/conferences/rubykaigi2048?tab=plans#top", BASE));
    assert.ok(matchSpaPath("conferences", "http://sponsor-app.localhost:1355/admin/"));
  });

  it("leaves other origins and other paths to the browser", () => {
    assert.ok(!matchSpaPath("http://sponsor-app-rails.localhost:1355/admin", BASE));
    assert.ok(!matchSpaPath("//example.invalid/admin", BASE));
    assert.ok(!matchSpaPath("/admin/conferences/rubykaigi2048/sponsors_yml", BASE));
    assert.ok(!matchSpaPath("mailto:info@example.invalid", BASE));
  });
});
