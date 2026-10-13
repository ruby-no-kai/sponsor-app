import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toJson } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import { Code, ConnectError } from "@connectrpc/connect";
import { BadRequestSchema } from "../../gen/google/rpc/error_details_pb.ts";
import {
  AdminSponsorEventInputSchema,
  AdminSponsorEventSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_sponsor_events_pb.ts";
import { SponsorEventStatus } from "../../gen/rubykaigi/sponsor_app/sponsor_event_status_pb.ts";
import {
  SponsorshipState,
  SponsorshipSummarySchema,
} from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import {
  SPONSOR_EVENT_LAYOUT,
  coHostChoices,
  sponsorEventInputFrom,
  sponsorEventValuesFrom,
} from "./sponsorEventForm.ts";
import type { SponsorEventInputInit, SponsorEventInputResult } from "./sponsorEventForm.ts";

const summary = (id: bigint, name: string, state: SponsorshipState = SponsorshipState.ACTIVE) =>
  create(SponsorshipSummarySchema, { id, name, state });

const event = create(AdminSponsorEventSchema, {
  id: 5n,
  slug: "example.com-1",
  title: "Ruby Night",
  status: SponsorEventStatus.PENDING,
  startsAt: timestampFromDate(new Date("2048-09-10T19:00:00Z")),
  url: "https://night.example.invalid",
  linkName: "Registration",
  price: "",
  capacity: "100",
  locationEn: "Tokyo",
  locationLocal: "東京",
  sponsorship: summary(1n, "Host"),
  coHosts: [summary(3n, "Third"), summary(2n, "Second")],
  adminComment: "Bring your badge",
});

function unwrap(result: SponsorEventInputResult): SponsorEventInputInit {
  if (result.kind !== "ok") assert.fail(`not converted: ${JSON.stringify(result.fields)}`);
  return result.input;
}

describe("sponsorEventValuesFrom and sponsorEventInputFrom", () => {
  it("name every form value after an AdminSponsorEventInput field", () => {
    assert.deepEqual(
      Object.keys(sponsorEventValuesFrom(event)).sort(),
      AdminSponsorEventInputSchema.fields.map((field) => field.jsonName).sort(),
    );
  });

  it("label every form value, so each violation names its field", () => {
    assert.deepEqual(
      Object.keys(SPONSOR_EVENT_LAYOUT.labels).sort(),
      Object.keys(sponsorEventValuesFrom(event)).sort(),
    );
  });

  it("give back the input the event was saved from, co-hosts in their order", () => {
    const values = sponsorEventValuesFrom(event);
    const input = create(AdminSponsorEventInputSchema, unwrap(sponsorEventInputFrom(values)));

    assert.equal(values.startsAt, "2048-09-10T19:00");
    assert.deepEqual(toJson(AdminSponsorEventInputSchema, input), {
      title: "Ruby Night",
      slug: "example.com-1",
      startsAt: "2048-09-10T19:00:00Z",
      url: "https://night.example.invalid",
      linkName: "Registration",
      capacity: "100",
      locationEn: "Tokyo",
      locationLocal: "東京",
      status: "SPONSOR_EVENT_STATUS_PENDING",
      coHostSponsorshipIds: ["3", "2"],
      adminComment: "Bring your badge",
    });
  });

  it("send an emptied start as none, which the server refuses", () => {
    const values = { ...sponsorEventValuesFrom(event), startsAt: "" };

    assert.equal(unwrap(sponsorEventInputFrom(values)).startsAt, undefined);
  });

  it("report a start the browser could not read on its field, without saving", () => {
    const values = { ...sponsorEventValuesFrom(event), startsAt: "2048-13-45T25:00" };

    assert.deepEqual(sponsorEventInputFrom(values), {
      kind: "invalid",
      fields: { startsAt: "Enter a date and time" },
    });
  });
});

describe("violations on co-hosts", () => {
  it("show on the co-host picker, as an ID has no field of its own", () => {
    const error = new ConnectError("invalid", Code.InvalidArgument, undefined, [
      {
        desc: BadRequestSchema,
        value: {
          fieldViolations: [
            { field: "input.coHostSponsorshipIds[1]", description: "value must be greater than 0" },
            { field: "input.title", description: "value must not be blank" },
          ],
        },
      },
    ]);
    const { fields } = fieldViolations(error, { prefix: "input." });
    const metas = Object.fromEntries(
      Object.entries(fields).map(([path, message]) => [path, { errors: [message] }]),
    );

    assert.deepEqual(erroredFields(metas, SPONSOR_EVENT_LAYOUT), [
      { path: "title", label: "Title", message: "must not be blank" },
      {
        path: "coHostSponsorshipIds",
        label: "Co-hosts",
        message: "#2: must be greater than 0",
      },
    ]);
  });
});

describe("coHostChoices", () => {
  const sponsorships = [
    summary(1n, "Host"),
    summary(2n, "Second"),
    summary(3n, "Third", SponsorshipState.WITHDRAWN),
  ];

  it("offers every sponsorship of the conference but the event's own, flagging withdrawn ones", () => {
    const choices = coHostChoices(sponsorships, { hostId: 1n, selected: [] });

    assert.deepEqual(choices.ids, ["2", "3"]);
    assert.equal(choices.label("2"), "Second #2");
    assert.equal(choices.label("3"), "Third #3 (withdrawn)");
  });

  it("keeps a selected co-host the picker does not list, so saving does not drop it", () => {
    const choices = coHostChoices(sponsorships, { hostId: 1n, selected: ["3", "1", "9"] });

    assert.deepEqual(choices.ids, ["2", "3", "1", "9"]);
    assert.equal(choices.label("1"), "#1");
    assert.equal(choices.label("9"), "#9");
  });
});
