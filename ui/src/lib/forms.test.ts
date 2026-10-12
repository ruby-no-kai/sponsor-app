import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import {
  formatTimestamp,
  idFromInput,
  idToInput,
  optionalFromInput,
  optionalToInput,
  timestampFromInput,
  timestampToInput,
} from "./forms.ts";

// Date reads TZ on every call, so the local-time conversions below run in a fixed zone.
process.env.TZ = "Asia/Tokyo";

describe("IDs", () => {
  it("round-trips int64 beyond Number's precision", () => {
    assert.equal(idToInput(9007199254740993n), "9007199254740993");
    assert.equal(idFromInput("9007199254740993"), 9007199254740993n);
  });

  it("rejects what is not an ID", () => {
    assert.throws(() => idFromInput(""), RangeError);
    assert.throws(() => idFromInput("1e3"), RangeError);
  });
});

describe("optional strings", () => {
  it("leaves an empty input unset", () => {
    assert.equal(optionalFromInput(""), undefined);
    assert.equal(optionalFromInput("Gold"), "Gold");
    assert.equal(optionalToInput(undefined), "");
  });
});

describe("timestamps", () => {
  it("shows a timestamp in local time, to the minute", () => {
    const timestamp = timestampFromDate(new Date("2026-04-01T00:30:00Z"));

    assert.equal(timestampToInput(timestamp), "2026-04-01T09:30");
    assert.equal(timestampToInput(undefined), "");
  });

  it("keeps seconds when set", () => {
    assert.equal(
      timestampToInput(timestampFromDate(new Date("2026-04-01T00:30:15Z"))),
      "2026-04-01T09:30:15",
    );
  });

  it("reads datetime-local input as local time", () => {
    const timestamp = timestampFromInput("2026-04-01T09:30");

    assert.equal(timestamp?.seconds, BigInt(Date.parse("2026-04-01T00:30:00Z") / 1000));
    assert.equal(timestampFromInput(""), undefined);
    assert.throws(() => timestampFromInput("tomorrow"), RangeError);
  });
});

describe("formatTimestamp", () => {
  it("shows the zone along with the time", () => {
    assert.match(formatTimestamp(timestampFromDate(new Date("2026-04-01T00:30:00Z"))), /2026.*30/);
    assert.equal(formatTimestamp(undefined, "not scheduled"), "not scheduled");
  });
});
