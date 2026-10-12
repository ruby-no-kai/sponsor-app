import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { isSpaPathname, matchSpaPath } from "./paths.ts";

const BASE = "http://sponsor-app.localhost:1355/admin";

describe("isSpaPathname", () => {
  it("matches whole SPA paths only", () => {
    assert.ok(isSpaPathname("/admin"));
    assert.ok(isSpaPathname("/admin/conferences"));
    assert.ok(isSpaPathname("/admin/conferences/rubykaigi2048"));
    assert.ok(!isSpaPathname("/admin/conferences/rubykaigi2048/plans"));
    assert.ok(!isSpaPathname("/admin/conferences/new"));
    assert.ok(!isSpaPathname("/admin/conferences/new/"));
    assert.ok(!isSpaPathname("/admin/session/new"));
    assert.ok(!isSpaPathname("/"));
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
    assert.ok(!matchSpaPath("/admin/conferences/rubykaigi2048/edit", BASE));
    assert.ok(!matchSpaPath("/admin/conferences/new", BASE));
    assert.ok(!matchSpaPath("mailto:info@example.invalid", BASE));
  });
});
