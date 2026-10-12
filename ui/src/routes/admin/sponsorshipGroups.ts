import type { PlanSummary } from "../../gen/rubykaigi/sponsor_app/plan_summary_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import type { SponsorshipSummary } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";

// Sponsorships on one plan, or with no plan determined when planId is undefined.
export type SponsorshipGroup = {
  key: string;
  plan: PlanSummary | undefined;
  planId: bigint | undefined;
  sponsorships: SponsorshipSummary[];
};

const byId = (a: SponsorshipSummary, b: SponsorshipSummary) =>
  a.id < b.id ? -1 : a.id > b.id ? 1 : 0;

// Groups the sponsorships that have not withdrawn by plan, lowest rank first and undetermined last,
// each oldest application first. Withdrawn ones are set apart.
export function groupSponsorships(
  plans: readonly PlanSummary[],
  sponsorships: readonly SponsorshipSummary[],
): { groups: SponsorshipGroup[]; withdrawn: SponsorshipSummary[] } {
  const sorted = [...sponsorships].sort(byId);
  const groups = new Map<string, SponsorshipGroup>();

  for (const sponsorship of sorted) {
    if (sponsorship.state === SponsorshipState.WITHDRAWN) continue;
    const { planId } = sponsorship;
    const key = planId === undefined ? "undetermined" : planId.toString();
    let group = groups.get(key);
    if (group === undefined) {
      const plan =
        planId === undefined ? undefined : plans.find((candidate) => candidate.id === planId);
      group = { key, plan, planId, sponsorships: [] };
      groups.set(key, group);
    }
    group.sponsorships.push(sponsorship);
  }

  const rankOf = (group: SponsorshipGroup) => group.plan?.rank ?? Number.POSITIVE_INFINITY;
  const byRank = (a: SponsorshipGroup, b: SponsorshipGroup) =>
    rankOf(a) < rankOf(b) ? -1 : rankOf(a) > rankOf(b) ? 1 : 0;
  return {
    groups: [...groups.values()].sort(byRank),
    withdrawn: sorted.filter((sponsorship) => sponsorship.state === SponsorshipState.WITHDRAWN),
  };
}

// A group's counts as its heading shows them: active sponsorships against the plan's capacity, as
// the plans list counts them, then the applications awaiting acceptance.
export function groupCounts({ plan, sponsorships }: SponsorshipGroup): string {
  const active = sponsorships.filter(({ state }) => state === SponsorshipState.ACTIVE).length;
  const pending = sponsorships.length - active;
  const counts = [plan === undefined ? `${active} active` : `${active}/${plan.capacity} active`];
  if (pending > 0) counts.push(`${pending} pending`);
  return counts.join(", ");
}
