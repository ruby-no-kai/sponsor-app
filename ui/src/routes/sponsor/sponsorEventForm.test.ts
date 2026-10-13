import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import {
  SponsorEventAssetFileSchema,
  SponsorEventSchema,
} from "../../gen/rubykaigi/sponsor_app/sponsor_events_pb.ts";
import {
  eventImageHref,
  eventInputFrom,
  eventValuesFrom,
  needsEnglishAcknowledgement,
  validateEvent,
} from "./sponsorEventForm.ts";
import type { SponsorEventValues } from "./sponsorEventForm.ts";

const messages = {
  required: "required",
  url: "url",
  datetime: "datetime",
  acknowledge: "acknowledge",
  agree: "agree",
};

const event = create(SponsorEventSchema, {
  id: 5n,
  title: "Ruby Night",
  startsAt: timestampFromDate(new Date("2048-09-10T19:00:00Z")),
  url: "https://night.example.invalid",
  price: "Free",
  capacity: "100",
  locationEn: "Tokyo",
  locationLocal: "東京",
  assetFile: create(SponsorEventAssetFileSchema, { id: 9n, extension: "png" }),
});

const valid: SponsorEventValues = {
  ...eventValuesFrom(event),
  policyAgreement: true,
};

describe("eventValuesFrom", () => {
  it("starts a new event empty, with the policy unagreed", () => {
    assert.deepEqual(eventValuesFrom(undefined), {
      title: "",
      startsAt: "",
      url: "",
      price: "",
      capacity: "",
      locationEn: "",
      locationLocal: "",
      assetFileId: { kind: "none" },
      englishAcknowledged: false,
      policyAgreement: false,
    });
  });

  it("starts from the event, as the venue's wall clock, with the policy agreed", () => {
    assert.deepEqual(eventValuesFrom(event), {
      title: "Ruby Night",
      startsAt: "2048-09-10T19:00",
      url: "https://night.example.invalid",
      price: "Free",
      capacity: "100",
      locationEn: "Tokyo",
      locationLocal: "東京",
      assetFileId: { kind: "existing", id: "9" },
      englishAcknowledged: false,
      policyAgreement: true,
    });
  });
});

describe("eventValuesFrom with seconds", () => {
  it("drops the seconds of the start time, as the input shows minutes", () => {
    const withSeconds = create(SponsorEventSchema, {
      ...event,
      startsAt: timestampFromDate(new Date("2048-09-10T19:00:54Z")),
    });
    assert.equal(eventValuesFrom(withSeconds).startsAt, "2048-09-10T19:00");
  });
});

describe("needsEnglishAcknowledgement", () => {
  it("watches the title, price, capacity and English location together", () => {
    assert.equal(needsEnglishAcknowledgement(valid), false);
    for (const name of ["title", "price", "capacity", "locationEn"] as const) {
      assert.equal(needsEnglishAcknowledgement({ ...valid, [name]: "東京" }), true, name);
    }
  });

  it("leaves the local location free", () => {
    assert.equal(needsEnglishAcknowledgement({ ...valid, locationLocal: "東京タワー" }), false);
  });
});

describe("validateEvent", () => {
  it("accepts a complete event", () => {
    assert.equal(validateEvent(valid, { creating: true }, messages), undefined);
  });

  it("asks for a title, a start and a URL", () => {
    const values = { ...valid, title: " ", startsAt: "", url: "" };
    assert.deepEqual(validateEvent(values, { creating: false }, messages), {
      fields: { title: "required", startsAt: "required", url: "required" },
    });
  });

  it("asks for an http(s) URL", () => {
    assert.deepEqual(validateEvent({ ...valid, url: "ftp://x" }, { creating: false }, messages), {
      fields: { url: "url" },
    });
  });

  it("asks for the English acknowledgement only when a field looks non-English", () => {
    const values = { ...valid, title: "東京の夜" };
    assert.deepEqual(validateEvent(values, { creating: false }, messages), {
      fields: { englishAcknowledged: "acknowledge" },
    });
    assert.equal(
      validateEvent({ ...values, englishAcknowledged: true }, { creating: false }, messages),
      undefined,
    );
  });

  it("asks for the policy on a new event only", () => {
    const values = { ...valid, policyAgreement: false };
    assert.deepEqual(validateEvent(values, { creating: true }, messages), {
      fields: { policyAgreement: "agree" },
    });
    assert.equal(validateEvent(values, { creating: false }, messages), undefined);
  });
});

describe("eventInputFrom", () => {
  it("sends the start as the same reading in UTC", () => {
    const input = eventInputFrom(valid, 9n);
    assert.equal(input.startsAt?.seconds, BigInt(Date.parse("2048-09-10T19:00:00Z") / 1000));
    assert.equal(input.assetFileId, 9n);
    assert.equal(input.title, "Ruby Night");
  });

  it("leaves the image out to remove it", () => {
    assert.equal(eventInputFrom(valid, undefined).assetFileId, undefined);
  });

  it("sends no staff fields", () => {
    const keys = Object.keys(eventInputFrom(valid, undefined));
    for (const staff of ["slug", "status", "coHostSponsorshipIds", "linkName", "adminComment"]) {
      assert.ok(!keys.includes(staff), staff);
    }
  });
});

describe("eventImageHref", () => {
  it("names the Rails download page under the conference", () => {
    assert.equal(
      eventImageHref("rubykaigi2048", 9n),
      "/conferences/rubykaigi2048/event_asset_files/9",
    );
  });
});
