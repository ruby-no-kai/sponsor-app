import assert from "node:assert/strict";
import { after, before, describe, it } from "node:test";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import {
  formatTimestamp,
  formatVenueTimestamp,
  idFromInput,
  idFromParam,
  idToInput,
  int32FromInput,
  int32ToInput,
  nowInput,
  optionalFromInput,
  optionalInt32FromInput,
  optionalInt32ToInput,
  optionalToInput,
  timestampFromInput,
  timestampToInput,
  venueTimeFromInput,
  venueTimeToInput,
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

  it("reads a route parameter that names no ID as none", () => {
    assert.equal(idFromParam("42"), 42n);
    assert.equal(idFromParam("abc"), undefined);
    assert.equal(idFromParam("new"), undefined);
    assert.equal(idFromParam(""), undefined);
  });
});

describe("optional strings", () => {
  it("leaves an empty input unset", () => {
    assert.equal(optionalFromInput(""), undefined);
    assert.equal(optionalFromInput("Gold"), "Gold");
    assert.equal(optionalToInput(undefined), "");
  });
});

describe("int32", () => {
  it("round-trips a whole number", () => {
    assert.equal(int32FromInput(int32ToInput(-42)), -42);
    assert.equal(int32FromInput(" 7 "), 7);
  });

  it("rejects what an int32 cannot hold", () => {
    for (const value of ["", "1.5", "1e3", "0x10", "abc", "2147483648", "-2147483649"]) {
      assert.throws(() => int32FromInput(value), RangeError, value);
    }
    assert.equal(int32FromInput("2147483647"), 2147483647);
  });

  it("leaves an empty optional input unset rather than zero", () => {
    assert.equal(optionalInt32FromInput(""), undefined);
    assert.equal(optionalInt32FromInput("0"), 0);
    assert.equal(optionalInt32ToInput(undefined), "");
    assert.throws(() => optionalInt32FromInput("x"), RangeError);
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

describe("nowInput", () => {
  it("is the local time to the minute", () => {
    assert.equal(nowInput(new Date("2026-04-01T00:30:15.250Z")), "2026-04-01T09:30");
  });
});

describe("venue time", () => {
  for (const zone of ["Asia/Tokyo", "America/Los_Angeles", "UTC"]) {
    describe(`in ${zone}`, () => {
      const original = process.env.TZ;
      before(() => {
        process.env.TZ = zone;
      });
      after(() => {
        process.env.TZ = original;
      });

      it("shows the UTC reading, to the minute", () => {
        const timestamp = timestampFromDate(new Date("2026-12-10T19:00:00Z"));

        assert.equal(venueTimeToInput(timestamp), "2026-12-10T19:00");
        assert.equal(venueTimeToInput(undefined), "");
      });

      it("keeps seconds when set", () => {
        assert.equal(
          venueTimeToInput(timestampFromDate(new Date("2026-12-10T19:00:15Z"))),
          "2026-12-10T19:00:15",
        );
      });

      it("reads datetime-local input as the same reading in UTC", () => {
        const timestamp = venueTimeFromInput("2026-12-10T19:00");

        assert.equal(timestamp?.seconds, BigInt(Date.parse("2026-12-10T19:00:00Z") / 1000));
        assert.equal(venueTimeFromInput("2026-12-10T19:00:15")?.seconds, 1796929215n);
        assert.equal(venueTimeFromInput(""), undefined);
      });

      it("round-trips a wall clock the zone skips", () => {
        assert.equal(venueTimeToInput(venueTimeFromInput("2026-03-08T02:30")), "2026-03-08T02:30");
      });
    });
  }

  it("rejects what is no datetime-local value", () => {
    for (const value of ["tomorrow", "2026-13-45T25:00", "2026-12-10", "2026-12-10T19:00Z"])
      assert.throws(() => venueTimeFromInput(value), RangeError, value);
  });
});

describe("formatVenueTimestamp", () => {
  it("shows the UTC reading without a zone", () => {
    const text = formatVenueTimestamp(timestampFromDate(new Date("2026-12-10T19:00:00Z")));

    assert.match(text, /2026/);
    assert.match(text, /Dec|12/);
    assert.match(text, /19:00|7:00/);
    assert.doesNotMatch(text, /UTC|GMT/);
    assert.equal(formatVenueTimestamp(undefined, "not scheduled"), "not scheduled");
  });
});
