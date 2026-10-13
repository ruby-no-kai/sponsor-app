import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toJson } from "@bufbuild/protobuf";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { BroadcastRecipientFilterSchema } from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import {
  emailsFromInput,
  recipientFilterFrom,
  recipientFilterValues,
  sortedByName,
  sponsorshipDetailText,
} from "./recipientFilterForm.ts";
import type { RecipientFilterValues } from "./recipientFilterForm.ts";

function filterJson(values: RecipientFilterValues) {
  const init = recipientFilterFrom(values);
  if (init === undefined) assert.fail("no filter");
  return toJson(BroadcastRecipientFilterSchema, create(BroadcastRecipientFilterSchema, init));
}

describe("recipientFilterFrom", () => {
  it("makes no filter for none", () => {
    assert.equal(recipientFilterFrom(recipientFilterValues("none")), undefined);
  });

  it("sends only the chosen kind, leaving unset what the form leaves empty", () => {
    const values = recipientFilterValues("currentSponsors");
    values.pastSponsors.conferenceSlug = "rubykaigi2047";
    values.raw.emails = "a@example.invalid";

    assert.deepEqual(filterJson(values), { currentSponsors: {} });
  });

  it("converts every field of current sponsors", () => {
    const values = recipientFilterValues("currentSponsors");
    values.currentSponsors = {
      locale: "ja",
      exhibitorsOnly: true,
      planId: "12",
      status: "NOT_ACCEPTED",
    };

    assert.deepEqual(filterJson(values), {
      currentSponsors: {
        locale: "ja",
        exhibitorsOnly: true,
        planId: "12",
        status: "SPONSORSHIP_STATUS_NOT_ACCEPTED",
      },
    });
  });

  it("converts past sponsors", () => {
    const values = recipientFilterValues("pastSponsors");
    values.pastSponsors = { conferenceSlug: "rubykaigi2047", locale: "", status: "ACTIVE" };

    assert.deepEqual(filterJson(values), {
      pastSponsors: { conferenceSlug: "rubykaigi2047", status: "SPONSORSHIP_STATUS_ACTIVE" },
    });
  });

  it("converts picked sponsorships and addresses", () => {
    const manual = recipientFilterValues("manual");
    manual.manual.sponsorshipIds = ["3", "5"];
    const raw = recipientFilterValues("raw");
    raw.raw.emails = " a@example.invalid \r\n\nnot an address\n";

    assert.deepEqual(filterJson(manual), { manual: { sponsorshipIds: ["3", "5"] } });
    assert.deepEqual(filterJson(raw), { raw: { emails: ["a@example.invalid", "not an address"] } });
  });
});

describe("emailsFromInput", () => {
  it("reads one address per line, leaving duplicates for the server to report", () => {
    assert.deepEqual(emailsFromInput("a@example.invalid\n\n  a@example.invalid  \n"), [
      "a@example.invalid",
      "a@example.invalid",
    ]);
    assert.deepEqual(emailsFromInput(""), []);
  });
});

describe("sponsorshipDetailText", () => {
  it("names the plan and where the sponsorship stands", () => {
    assert.equal(sponsorshipDetailText(SponsorshipState.ACTIVE, "Gold"), "Gold, accepted");
    assert.equal(sponsorshipDetailText(SponsorshipState.PENDING, undefined), "no plan, pending");
  });
});

describe("sortedByName", () => {
  it("orders by name without touching the input", () => {
    const input = [{ name: "B" }, { name: "A" }];
    assert.deepEqual(sortedByName(input), [{ name: "A" }, { name: "B" }]);
    assert.deepEqual(input, [{ name: "B" }, { name: "A" }]);
  });
});
