import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import { SponsorEventStatus } from "../../gen/rubykaigi/sponsor_app/sponsor_event_status_pb.ts";
import {
  SponsorshipState,
  SponsorshipSummarySchema,
} from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import {
  EDITABLE_STATUSES,
  SPONSOR_EVENT_STATUS_LABELS,
  linkText,
  locationText,
  priceText,
  publishedHosts,
} from "./sponsorEventView.ts";
import { labelOf } from "./sponsorshipView.ts";

const summary = (id: bigint, state: SponsorshipState = SponsorshipState.ACTIVE) =>
  create(SponsorshipSummarySchema, { id, name: `Sponsor ${id}`, state });

describe("publishedHosts", () => {
  it("names the submitting sponsorship, then the co-hosts, leaving out withdrawn ones", () => {
    const hosts = publishedHosts({
      sponsorship: summary(1n),
      coHosts: [summary(2n, SponsorshipState.WITHDRAWN), summary(3n)],
    });

    assert.deepEqual(
      hosts.map((host) => host.id),
      [1n, 3n],
    );
  });

  it("names none when every host withdrew", () => {
    assert.deepEqual(
      publishedHosts({ sponsorship: summary(1n, SponsorshipState.WITHDRAWN), coHosts: [] }),
      [],
    );
  });
});

describe("priceText", () => {
  it("shows an event without a price as free", () => {
    assert.equal(priceText(""), "Free");
    assert.equal(priceText("1000 JPY"), "1000 JPY");
  });
});

describe("locationText", () => {
  it("names the venue in English, then locally when that differs", () => {
    assert.equal(locationText({ locationEn: "Tokyo", locationLocal: "東京" }), "Tokyo / 東京");
    assert.equal(locationText({ locationEn: "Tokyo", locationLocal: "Tokyo" }), "Tokyo");
    assert.equal(locationText({ locationEn: "", locationLocal: "東京" }), "東京");
    assert.equal(locationText({ locationEn: "", locationLocal: "" }), undefined);
  });
});

describe("statuses", () => {
  it("offer and label every status but the unspecified one", () => {
    const defined = Object.values(SponsorEventStatus).filter(
      (value) => value !== SponsorEventStatus.UNSPECIFIED,
    );

    assert.deepEqual([...EDITABLE_STATUSES].sort(), defined.sort());
    assert.equal(
      labelOf(SPONSOR_EVENT_STATUS_LABELS, SponsorEventStatus.ACCEPTED).text,
      "Accepted",
    );
  });
});

describe("linkText", () => {
  it("prefers the link name", () => {
    assert.equal(
      linkText({ linkName: "Registration", url: "https://a.example.invalid/x" }),
      "Registration",
    );
  });

  it("falls back to the host, then to the text itself", () => {
    assert.equal(
      linkText({ linkName: "", url: "https://a.example.invalid:8443/x" }),
      "a.example.invalid:8443",
    );
    assert.equal(linkText({ linkName: "", url: "not a url" }), "not a url");
  });
});
