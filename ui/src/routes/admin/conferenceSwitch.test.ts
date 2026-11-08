import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { paths } from "../paths.ts";
import { switchedConferencePath } from "./conferenceSwitch.ts";

const SECTIONS = [paths.conference, paths.plans, paths.broadcasts, paths.conferenceEdit];

describe("switchedConferencePath", () => {
  it("keeps the section", () => {
    assert.equal(
      switchedConferencePath("/admin/conferences/a/plans", SECTIONS, "b"),
      "/admin/conferences/b/plans",
    );
    assert.equal(
      switchedConferencePath("/admin/conferences/a/edit", SECTIONS, "b"),
      "/admin/conferences/b/edit",
    );
  });

  it("lands on the section's list from a record in it", () => {
    assert.equal(
      switchedConferencePath("/admin/conferences/a/broadcasts/12/edit", SECTIONS, "b"),
      "/admin/conferences/b/broadcasts",
    );
  });

  it("lands on the overview from a page outside every section", () => {
    assert.equal(
      switchedConferencePath("/admin/conferences/a/sponsorships/3", SECTIONS, "b"),
      "/admin/conferences/b",
    );
    assert.equal(
      switchedConferencePath("/admin/organizations", SECTIONS, "b"),
      "/admin/conferences/b",
    );
  });
});
