import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import {
  formatDate,
  formatDateRange,
  formatDateTime,
  formatVenueDate,
  formatVenueDateTime,
} from "./dates.ts";

describe("formatDate", () => {
  it("shows the day without a time", () => {
    const day = formatDate(timestampFromDate(new Date("2026-09-13T00:30:00Z")));
    assert.match(day, /2026/);
    assert.doesNotMatch(day, /:/);
    assert.equal(formatDate(undefined, "not scheduled"), "not scheduled");
  });
});

describe("formatDateRange", () => {
  it("joins the days with an en dash", () => {
    const from = timestampFromDate(new Date("2026-09-13T00:30:00Z"));
    const to = timestampFromDate(new Date("2026-11-13T00:30:00Z"));
    assert.match(formatDateRange(from, to), /2026 – .*2026/);
    assert.equal(
      formatDateRange(undefined, undefined, { from: "not scheduled", to: "no deadline" }),
      "not scheduled – no deadline",
    );
  });
});

describe("formatDateTime", () => {
  it("shows the time without seconds or a zone", () => {
    const text = formatDateTime(timestampFromDate(new Date("2026-09-13T00:30:15Z")));
    assert.match(text, /2026/);
    assert.doesNotMatch(text, /:\d\d:\d\d|GMT|UTC/);
    assert.equal(formatDateTime(undefined, "never"), "never");
  });
});

describe("formatVenueDate", () => {
  it("shows the UTC day, whatever the browser's time zone is", () => {
    const day = formatVenueDate(timestampFromDate(new Date("2026-09-13T23:30:00Z")));
    assert.match(day, /13/);
    assert.match(day, /2026/);
    assert.doesNotMatch(day, /:/);
    assert.equal(formatVenueDate(undefined, "not scheduled"), "not scheduled");
  });
});

describe("formatVenueDateTime", () => {
  it("shows the UTC reading in the locale, naming no zone", () => {
    const timestamp = timestampFromDate(new Date("2026-09-13T19:00:00Z"));
    const en = formatVenueDateTime(timestamp, "en");
    assert.match(en, /Sep 13, 2026.*7:00/);
    assert.doesNotMatch(en, /UTC|GMT/);
    assert.match(formatVenueDateTime(timestamp, "ja"), /2026年9月13日.*19:00/);
  });
});
