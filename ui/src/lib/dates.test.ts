import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import { formatDate, formatDateRange, formatDateTime } from "./dates.ts";

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
