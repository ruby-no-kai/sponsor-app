import type { MessageInitShape } from "@bufbuild/protobuf";
import type {
  AdminSponsorEvent,
  AdminSponsorEventInputSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_sponsor_events_pb.ts";
import type { SponsorEventStatus } from "../../gen/rubykaigi/sponsor_app/sponsor_event_status_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import type { SponsorshipSummary } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { idFromInput, idToInput, venueTimeFromInput, venueTimeToInput } from "../../lib/forms.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";

// Named after AdminSponsorEventInput's JSON fields, so a google.rpc.BadRequest field path below
// "input." is the name of the form field it concerns.
export type SponsorEventValues = {
  title: string;
  slug: string;
  startsAt: string;
  url: string;
  linkName: string;
  price: string;
  capacity: string;
  locationEn: string;
  locationLocal: string;
  status: SponsorEventStatus;
  coHostSponsorshipIds: string[];
  adminComment: string;
};

// What the editor labels each field, in the order it lays them out.
export const FIELD_LABELS: Readonly<Record<keyof SponsorEventValues, string>> = {
  title: "Title",
  slug: "Slug",
  startsAt: "Starts at",
  url: "URL",
  linkName: "Link name",
  price: "Price",
  capacity: "Capacity",
  locationEn: "Location (English)",
  locationLocal: "Location (local)",
  status: "Status",
  coHostSponsorshipIds: "Co-hosts",
  adminComment: "Admin comment",
};

export const SPONSOR_EVENT_LAYOUT: FieldLayout = { labels: FIELD_LABELS };

// The values held as text, which are every one but the status and the co-hosts.
export type SponsorEventTextField = {
  [K in keyof SponsorEventValues]: SponsorEventValues[K] extends string ? K : never;
}[keyof SponsorEventValues];

export type SponsorEventInputInit = MessageInitShape<typeof AdminSponsorEventInputSchema>;

export type SponsorEventInputResult =
  | { kind: "ok"; input: SponsorEventInputInit }
  | { kind: "invalid"; fields: Record<string, string> };

export function sponsorEventValuesFrom(event: AdminSponsorEvent): SponsorEventValues {
  return {
    title: event.title,
    slug: event.slug,
    startsAt: venueTimeToInput(event.startsAt),
    url: event.url,
    linkName: event.linkName,
    price: event.price,
    capacity: event.capacity,
    locationEn: event.locationEn,
    locationLocal: event.locationLocal,
    status: event.status,
    coHostSponsorshipIds: event.coHosts.map((host) => idToInput(host.id)),
    adminComment: event.adminComment,
  };
}

// Every rule is the server's. Only a start the message cannot carry is reported here, as it never
// reaches the server.
export function sponsorEventInputFrom(values: SponsorEventValues): SponsorEventInputResult {
  const { startsAt, coHostSponsorshipIds, ...fields } = values;
  let startsAtInput;
  try {
    startsAtInput = venueTimeFromInput(startsAt);
  } catch (error) {
    if (!(error instanceof RangeError)) throw error;
    return { kind: "invalid", fields: { startsAt: "Enter a date and time" } };
  }
  return {
    kind: "ok",
    input: {
      ...fields,
      startsAt: startsAtInput,
      coHostSponsorshipIds: coHostSponsorshipIds.map(idFromInput),
    },
  };
}

export type CoHostChoices = {
  // Sponsorship IDs in the order the picker lists them.
  ids: string[];
  label: (id: string) => string;
};

// Every sponsorship of the conference but the event's own, then any selected co-host missing from
// that list, such as the host itself or one newer than the cached conference, so saving keeps it.
export function coHostChoices(
  sponsorships: readonly SponsorshipSummary[],
  {
    hostId,
    selected,
  }: {
    hostId: bigint | undefined;
    selected: readonly string[];
  },
): CoHostChoices {
  const labels = new Map<string, string>();
  for (const sponsorship of sponsorships) {
    if (sponsorship.id === hostId) continue;
    const withdrawn = sponsorship.state === SponsorshipState.WITHDRAWN ? " (withdrawn)" : "";
    labels.set(idToInput(sponsorship.id), `${sponsorship.name} #${sponsorship.id}${withdrawn}`);
  }
  const ids = [...labels.keys(), ...selected.filter((id) => !labels.has(id))];
  return { ids, label: (id) => labels.get(id) ?? `#${id}` };
}
