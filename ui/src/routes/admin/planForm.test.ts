import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toJson } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import {
  AdminPlanSchema,
  PlanInputSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_plans_pb.ts";
import { planInputFrom, planValuesFrom } from "./planForm.ts";
import type { PlanInputInit, PlanInputResult } from "./planForm.ts";

// Date reads TZ on every call, so the local-time conversions below run in a fixed zone.
process.env.TZ = "Asia/Tokyo";

const plan = create(AdminPlanSchema, {
  id: 12n,
  name: "Platinum",
  rank: 2,
  summary: "The top tier",
  priceText: "3,000,000 JPY",
  price: "3000000.0",
  priceBooth: "500000.5",
  capacity: 3,
  numberOfGuests: 4,
  boothSize: 0,
  wordsLimit: 200,
  autoAcceptance: false,
  talkable: true,
  closesAt: timestampFromDate(new Date("2026-03-01T03:00:00Z")),
  activeSponsorshipCount: 3,
  soldOut: true,
});

function unwrap(result: PlanInputResult): PlanInputInit {
  if (result.kind !== "ok") assert.fail(`not converted: ${JSON.stringify(result.fields)}`);
  return result.input;
}

function inputOf(result: PlanInputResult) {
  return toJson(PlanInputSchema, create(PlanInputSchema, unwrap(result)));
}

describe("planValuesFrom and planInputFrom", () => {
  it("name every form value after a PlanInput field", () => {
    assert.deepEqual(
      Object.keys(planValuesFrom(undefined)).sort(),
      PlanInputSchema.fields.map((field) => field.jsonName).sort(),
    );
  });

  it("give back the input a plan was saved from", () => {
    const values = planValuesFrom(plan);

    assert.equal(values.closesAt, "2026-03-01T12:00");
    assert.deepEqual(inputOf(planInputFrom(values)), {
      name: "Platinum",
      rank: 2,
      summary: "The top tier",
      priceText: "3,000,000 JPY",
      price: "3000000.0",
      priceBooth: "500000.5",
      capacity: 3,
      numberOfGuests: 4,
      boothSize: 0,
      wordsLimit: 200,
      talkable: true,
      closesAt: "2026-03-01T03:00:00Z",
    });
  });

  it("leave empty optional fields unset", () => {
    const values = { ...planValuesFrom(plan), summary: "", boothSize: "", closesAt: "" };
    const input = create(PlanInputSchema, unwrap(planInputFrom(values)));

    assert.equal(input.summary, undefined);
    assert.equal(input.boothSize, undefined);
    assert.equal(input.closesAt, undefined);
  });

  it("start a new plan from the table's defaults, leaving the capacity and words limit for the server to ask for", () => {
    const input = create(PlanInputSchema, unwrap(planInputFrom(planValuesFrom(undefined))));

    assert.equal(input.rank, 0);
    assert.equal(input.capacity, undefined);
    assert.equal(input.wordsLimit, undefined);
  });

  it("leave decimal prices to the server's rules", () => {
    const input = unwrap(
      planInputFrom({ ...planValuesFrom(plan), price: "1,000", priceBooth: "" }),
    );

    assert.equal(input.price, "1,000");
    assert.equal(input.priceBooth, "");
  });

  it("report each value the message cannot carry on its field", () => {
    const values = {
      ...planValuesFrom(plan),
      rank: "1.5",
      numberOfGuests: "",
      boothSize: "x",
      closesAt: "tomorrow",
    };

    assert.deepEqual(planInputFrom(values), {
      kind: "invalid",
      fields: {
        rank: "Enter a whole number",
        boothSize: "Enter a whole number",
        closesAt: "Enter a date and time",
      },
    });
  });
});
