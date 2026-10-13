import type { AdminSponsorEvent } from "../../gen/rubykaigi/sponsor_app/admin_sponsor_events_pb.ts";
import { SponsorEventStatus } from "../../gen/rubykaigi/sponsor_app/sponsor_event_status_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import type { SponsorshipSummary } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import type { Label } from "./sponsorshipView.ts";

export const SPONSOR_EVENT_STATUS_LABELS: Readonly<Record<SponsorEventStatus, Label>> = {
  [SponsorEventStatus.UNSPECIFIED]: { text: "Unknown", tone: "outline" },
  [SponsorEventStatus.PENDING]: { text: "Pending", tone: "warning" },
  [SponsorEventStatus.ACCEPTED]: { text: "Accepted", tone: "success" },
  [SponsorEventStatus.REJECTED]: { text: "Rejected", tone: "error" },
  [SponsorEventStatus.WITHDRAWN]: { text: "Withdrawn", tone: "outline" },
};

// The statuses an editor offers, in review order.
export const EDITABLE_STATUSES: readonly SponsorEventStatus[] = [
  SponsorEventStatus.PENDING,
  SponsorEventStatus.ACCEPTED,
  SponsorEventStatus.REJECTED,
  SponsorEventStatus.WITHDRAWN,
];

// The hosts the conference website names: the submitting sponsorship, then the co-hosts, leaving
// out withdrawn ones.
export function publishedHosts(
  event: Pick<AdminSponsorEvent, "sponsorship" | "coHosts">,
): SponsorshipSummary[] {
  return [...(event.sponsorship === undefined ? [] : [event.sponsorship]), ...event.coHosts].filter(
    (host) => host.state !== SponsorshipState.WITHDRAWN,
  );
}

// An event without a price is free, as listings show it.
export function priceText(price: string): string {
  return price === "" ? "Free" : price;
}

// The venue in English, followed by the local name when that differs.
export function locationText(
  event: Pick<AdminSponsorEvent, "locationEn" | "locationLocal">,
): string | undefined {
  const { locationEn, locationLocal } = event;
  const names = [locationEn, ...(locationLocal === locationEn ? [] : [locationLocal])];
  const given = names.filter((name) => name !== "");
  return given.length === 0 ? undefined : given.join(" / ");
}

// What a link to the event's URL reads: the link name when given, else the URL's host.
export function linkText(event: Pick<AdminSponsorEvent, "linkName" | "url">): string {
  if (event.linkName !== "") return event.linkName;
  try {
    return new URL(event.url).host;
  } catch {
    return event.url;
  }
}
