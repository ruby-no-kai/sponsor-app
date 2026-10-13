import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toJson } from "@bufbuild/protobuf";
import {
  AdminAnnouncementSchema,
  AdminAnnouncementSummarySchema,
  AnnouncementInputSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_announcements_pb.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import {
  ANNOUNCEMENT_LAYOUT,
  ANNOUNCEMENT_LOCALES,
  announcementInputFrom,
  announcementNewPath,
  announcementPath,
  announcementEditPath,
  announcementValuesFrom,
  defaultLocale,
  localeItems,
  parseAnnouncementId,
} from "./announcementForm.ts";

describe("announcement paths", () => {
  it("spell the ID as HAML does, issue then locale", () => {
    assert.equal(
      announcementPath("rubykaigi2048", "Hx3k_2Lp0aQ", "ja"),
      "/admin/conferences/rubykaigi2048/announcements/Hx3k_2Lp0aQ:ja",
    );
    assert.equal(
      announcementEditPath("rubykaigi2048", "Hx3k_2Lp0aQ", "ja"),
      "/admin/conferences/rubykaigi2048/announcements/Hx3k_2Lp0aQ:ja/edit",
    );
  });

  it("carry the issue a new locale joins in the query", () => {
    assert.equal(
      announcementNewPath("rubykaigi2048"),
      "/admin/conferences/rubykaigi2048/announcements/new",
    );
    assert.equal(
      announcementNewPath("rubykaigi2048", "a b&c"),
      "/admin/conferences/rubykaigi2048/announcements/new?issue=a+b%26c",
    );
  });
});

describe("parseAnnouncementId", () => {
  it("splits at the first colon", () => {
    assert.deepEqual(parseAnnouncementId("Hx3k_2Lp0aQ:ja"), { issue: "Hx3k_2Lp0aQ", locale: "ja" });
    assert.deepEqual(parseAnnouncementId("a:b:c"), { issue: "a", locale: "b:c" });
  });

  it("rejects an ID missing either part", () => {
    assert.equal(parseAnnouncementId("Hx3k_2Lp0aQ"), undefined);
    assert.equal(parseAnnouncementId(":ja"), undefined);
    assert.equal(parseAnnouncementId("Hx3k_2Lp0aQ:"), undefined);
  });
});

describe("locales", () => {
  it("are the ones AnnouncementInput accepts", () => {
    assert.deepEqual(ANNOUNCEMENT_LOCALES, ["en", "ja"]);
  });

  it("default to the first one the issue is not written in", () => {
    assert.equal(defaultLocale([]), "en");
    assert.equal(defaultLocale(["en"]), "ja");
    assert.equal(defaultLocale(["en", "ja"]), "");
  });

  it("mark the ones the issue is written in, and keep a stored locale listed", () => {
    assert.deepEqual(localeItems(["en"], "ja"), [
      { label: "en (written)", value: "en" },
      { label: "ja", value: "ja" },
    ]);
    assert.deepEqual(localeItems(["en", "fr"], "fr"), [
      { label: "en (written)", value: "en" },
      { label: "ja", value: "ja" },
      { label: "fr", value: "fr" },
    ]);
  });
});

describe("announcementValuesFrom and announcementInputFrom", () => {
  const saved = create(AdminAnnouncementSchema, {
    issue: "Hx3k_2Lp0aQ",
    locale: "en",
    title: "Booth setup",
    body: "Doors open at *8:00*.",
    bodyHtml: "<p>Doors open at <em>8:00</em>.</p>",
    published: true,
    pinned: true,
    exhibitorsOnly: true,
    revision: 2,
  });

  it("give back the input an announcement was saved from, never requesting a translation", () => {
    const input = create(
      AnnouncementInputSchema,
      announcementInputFrom(announcementValuesFrom(saved)),
    );

    assert.deepEqual(toJson(AnnouncementInputSchema, input), {
      locale: "en",
      title: "Booth setup",
      body: "Doors open at *8:00*.",
      pinned: true,
      exhibitorsOnly: true,
      published: true,
    });
  });

  it("start a new locale of an issue as a draft read by the same sponsors", () => {
    const sibling = create(AdminAnnouncementSummarySchema, {
      locale: "en",
      published: true,
      pinned: true,
      exhibitorsOnly: true,
    });

    assert.deepEqual(announcementValuesFrom(undefined, { locale: "ja", sibling }), {
      locale: "ja",
      title: "",
      body: "",
      pinned: true,
      exhibitorsOnly: true,
      published: false,
      newRevision: false,
    });
  });

  it("start a new issue unpinned and for every sponsor", () => {
    assert.deepEqual(announcementValuesFrom(undefined, { locale: "en" }), {
      locale: "en",
      title: "",
      body: "",
      pinned: false,
      exhibitorsOnly: false,
      published: false,
      newRevision: false,
    });
  });
});

describe("ANNOUNCEMENT_LAYOUT", () => {
  it("orders errors as the editor lays the fields out", () => {
    const errored = erroredFields(
      { body: { errors: ["can't be blank"] }, locale: { errors: ["already written"] } },
      ANNOUNCEMENT_LAYOUT,
    );

    assert.deepEqual(errored, [
      { path: "locale", label: "Locale", message: "already written" },
      { path: "body", label: "Body", message: "can't be blank" },
    ]);
  });
});
