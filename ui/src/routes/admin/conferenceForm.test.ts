import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toJson } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import { AdminConferenceSchema } from "../../gen/rubykaigi/sponsor_app/admin_conference_pb.ts";
import { ConferenceInputSchema } from "../../gen/rubykaigi/sponsor_app/admin_conferences_pb.ts";
import { DATE_TIME_FIELDS, formValuesFrom, inputFrom, nowInput } from "./conferenceForm.ts";
import type { ConferenceValues } from "./conferenceForm.ts";

// Date reads TZ on every call, so the local-time conversions below run in a fixed zone.
process.env.TZ = "Asia/Tokyo";

function inputOf(values: ConferenceValues) {
  const result = inputFrom(values);
  assert.equal(result.kind, "ok");
  return create(ConferenceInputSchema, result.kind === "ok" ? result.input : {});
}

const conference = create(AdminConferenceSchema, {
  conference: {
    slug: "rubykaigi2026",
    name: "RubyKaigi 2026",
    contactEmailAddress: "sponsorships@rubykaigi.example.invalid",
    applicationOpensAt: timestampFromDate(new Date("2026-01-15T00:00:00Z")),
    amendmentClosesAt: timestampFromDate(new Date("2026-03-01T03:00:30Z")),
    noPlanAllowed: false,
    additionalAttendeesRegistrationOpen: true,
  },
  hidden: true,
  allowRestrictedAccess: true,
  boothCapacity: 30,
  githubRepo: "ruby-no-kai/rubykaigi.org@master:data/sponsors.yml",
  titoSlug: "rubykaigi/2026",
  titoBoothPaidFlatDiscountAmount: "15000.0",
});

describe("formValuesFrom and inputFrom", () => {
  it("give back the input a conference was saved from", () => {
    const values = formValuesFrom(conference);
    const input = inputOf(values);

    assert.equal(values.applicationOpensAt, "2026-01-15T09:00");
    assert.equal(values.amendmentClosesAt, "2026-03-01T12:00:30");
    assert.equal(values.boothCapacity, "30");
    assert.deepEqual(toJson(ConferenceInputSchema, input), {
      name: "RubyKaigi 2026",
      slug: "rubykaigi2026",
      contactEmailAddress: "sponsorships@rubykaigi.example.invalid",
      applicationOpensAt: "2026-01-15T00:00:00Z",
      amendmentClosesAt: "2026-03-01T03:00:30Z",
      boothCapacity: 30,
      additionalAttendeesRegistrationOpen: true,
      hidden: true,
      allowRestrictedAccess: true,
      githubRepo: "ruby-no-kai/rubykaigi.org@master:data/sponsors.yml",
      titoSlug: "rubykaigi/2026",
      titoBoothPaidFlatDiscountAmount: "15000.0",
    });
  });

  it("start a new conference with the defaults of the conferences table", () => {
    const values = formValuesFrom(undefined);

    assert.equal(values.noPlanAllowed, true);
    assert.equal(values.boothCapacity, "0");
    assert.equal(values.titoBoothPaidFlatDiscountAmount, "0");
    assert.equal(values.allowRestrictedAccess, false);
  });

  it("leaves empty optional fields unset rather than empty", () => {
    const input = inputOf({
      ...formValuesFrom(conference),
      githubRepo: "",
      applicationOpensAt: "",
    });

    assert.equal(input.githubRepo, undefined);
    assert.equal(input.applicationOpensAt, undefined);
    assert.equal(input.titoSlug, "rubykaigi/2026");
  });

  it("names every field after the input's JSON field, so violations land on them", () => {
    const names = Object.keys(formValuesFrom(undefined)).sort();
    const jsonNames = ConferenceInputSchema.fields.map((field) => field.jsonName).sort();

    assert.deepEqual(names, jsonNames);
    for (const { name } of DATE_TIME_FIELDS) assert.ok(jsonNames.includes(name), name);
  });
});

describe("inputFrom", () => {
  it("leaves an emptied booth capacity unset, for the server to refuse", () => {
    assert.equal(
      inputOf({ ...formValuesFrom(conference), boothCapacity: "" }).boothCapacity,
      undefined,
    );
  });

  it("refuses a booth capacity no whole number, which the message cannot carry", () => {
    assert.deepEqual(inputFrom({ ...formValuesFrom(conference), boothCapacity: "1.5" }), {
      kind: "invalid",
      fields: { boothCapacity: "Enter a whole number" },
    });
  });
});

describe("nowInput", () => {
  it("is the local time to the second", () => {
    assert.equal(nowInput(new Date("2026-04-01T00:30:15.250Z")), "2026-04-01T09:30:15");
  });
});
