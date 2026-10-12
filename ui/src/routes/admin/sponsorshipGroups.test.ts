import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import { PlanSummarySchema } from "../../gen/rubykaigi/sponsor_app/plan_summary_pb.ts";
import {
  SponsorshipState,
  SponsorshipSummarySchema,
} from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { groupCounts, groupSponsorships } from "./sponsorshipGroups.ts";

const gold = create(PlanSummarySchema, { id: 10n, name: "Gold", rank: 2, capacity: 8 });
const ruby = create(PlanSummarySchema, { id: 11n, name: "Ruby", rank: 1, capacity: 2 });

const sponsorship = (
  id: bigint,
  planId: bigint | undefined,
  state: SponsorshipState = SponsorshipState.ACTIVE,
) => create(SponsorshipSummarySchema, { id, name: `Sponsor ${id}`, planId, state });

describe("groupSponsorships", () => {
  it("groups by plan rank, undetermined last, each oldest first, setting withdrawn apart", () => {
    const { groups, withdrawn } = groupSponsorships(
      [ruby, gold],
      [
        sponsorship(5n, 10n),
        sponsorship(1n, undefined, SponsorshipState.PENDING),
        sponsorship(4n, 11n, SponsorshipState.WITHDRAWN),
        sponsorship(3n, 10n, SponsorshipState.PENDING),
        sponsorship(2n, 11n),
      ],
    );

    assert.deepEqual(
      groups.map((group) => [group.plan?.name, group.sponsorships.map(({ id }) => id)]),
      [
        ["Ruby", [2n]],
        ["Gold", [3n, 5n]],
        [undefined, [1n]],
      ],
    );
    assert.deepEqual(
      withdrawn.map(({ id }) => id),
      [4n],
    );
  });

  it("leaves out plans nobody sponsors", () => {
    assert.deepEqual(groupSponsorships([ruby, gold], []).groups, []);
  });
});

describe("groupCounts", () => {
  it("counts active sponsorships against the capacity, and pending ones apart", () => {
    const { groups } = groupSponsorships(
      [ruby, gold],
      [
        sponsorship(1n, 10n),
        sponsorship(2n, 10n, SponsorshipState.PENDING),
        sponsorship(3n, 11n, SponsorshipState.PENDING),
        sponsorship(4n, undefined),
      ],
    );

    assert.deepEqual(groups.map(groupCounts), [
      "0/2 active, 1 pending",
      "1/8 active, 1 pending",
      "1 active",
    ]);
  });
});
