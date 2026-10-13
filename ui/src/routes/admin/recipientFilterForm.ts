import type { MessageInitShape } from "@bufbuild/protobuf";
import { BroadcastRecipientFilter_SponsorshipStatus } from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import type { BroadcastRecipientFilterSchema } from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { idFromInput, optionalFromInput } from "../../lib/forms.ts";

// A case of BroadcastRecipientFilter's `kind` oneof, or "none" for no filter at all.
export type RecipientFilterKind = "none" | "currentSponsors" | "pastSponsors" | "manual" | "raw";

export type SponsorshipStatusName = keyof typeof BroadcastRecipientFilter_SponsorshipStatus;

// Named after BroadcastRecipientFilter's JSON fields, so a google.rpc.BadRequest field path below
// "recipientFilter." names the value it concerns. Every kind keeps its values while another is
// chosen.
export type RecipientFilterValues = {
  kind: RecipientFilterKind;
  currentSponsors: {
    locale: string;
    exhibitorsOnly: boolean;
    planId: string;
    status: SponsorshipStatusName;
  };
  pastSponsors: { conferenceSlug: string; locale: string; status: SponsorshipStatusName };
  manual: { sponsorshipIds: string[] };
  raw: { emails: string };
};

export type RecipientFilterInit = MessageInitShape<typeof BroadcastRecipientFilterSchema>;

// What the fields are labelled, in the order they are laid out.
export const RECIPIENT_FILTER_LABELS: Readonly<Record<string, string>> = {
  recipientFilter: "Recipients",
  kind: "Who gets the email",
  currentSponsors: "Sponsors of this conference",
  pastSponsors: "Sponsors of a past conference",
  manual: "Picked sponsors",
  raw: "Addresses",
  conferenceSlug: "Conference",
  locale: "Locale",
  planId: "Plan",
  exhibitorsOnly: "Only sponsors assigned a booth",
  status: "Status",
  sponsorshipIds: "Sponsorships",
  emails: "Email addresses",
};

export const KIND_ITEMS: readonly { label: string; value: RecipientFilterKind }[] = [
  { label: "None", value: "none" },
  { label: "Sponsors of this conference", value: "currentSponsors" },
  { label: "Sponsors of a past conference", value: "pastSponsors" },
  { label: "Sponsors of this conference, picked one by one", value: "manual" },
  { label: "Email addresses", value: "raw" },
];

// A Select shows an empty value as its placeholder, in a pale colour. "Any" is a choice, so it
// goes by this value instead and the form keeps "".
export const ANY = "any";

export const LOCALE_ITEMS: readonly { label: string; value: string }[] = [
  { label: "Any", value: ANY },
  { label: "English", value: "en" },
  { label: "Japanese", value: "ja" },
];

export const STATUS_ITEMS: readonly { label: string; value: SponsorshipStatusName }[] = [
  { label: "All", value: "UNSPECIFIED" },
  { label: "Pending", value: "PENDING" },
  { label: "Active", value: "ACTIVE" },
  { label: "Not accepted (incl. withdrawn)", value: "NOT_ACCEPTED" },
  { label: "Accepted (incl. withdrawn)", value: "ACCEPTED" },
  { label: "Withdrawn", value: "WITHDRAWN" },
];

export function isRecipientFilterKind(value: unknown): value is RecipientFilterKind {
  return KIND_ITEMS.some((item) => item.value === value);
}

export function isSponsorshipStatusName(value: unknown): value is SponsorshipStatusName {
  return STATUS_ITEMS.some((item) => item.value === value);
}

export function recipientFilterValues(kind: RecipientFilterKind): RecipientFilterValues {
  return {
    kind,
    currentSponsors: { locale: "", exhibitorsOnly: false, planId: "", status: "UNSPECIFIED" },
    pastSponsors: { conferenceSlug: "", locale: "", status: "UNSPECIFIED" },
    manual: { sponsorshipIds: [] },
    raw: { emails: "" },
  };
}

// One address per line. Blank lines are left out, and anything else goes to the server as typed.
export function emailsFromInput(text: string): string[] {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line !== "");
}

// The filter the chosen kind's values make, or undefined for "none". Every rule is the server's.
export function recipientFilterFrom(
  values: RecipientFilterValues,
): RecipientFilterInit | undefined {
  switch (values.kind) {
    case "none":
      return undefined;
    case "currentSponsors": {
      const { locale, exhibitorsOnly, planId, status } = values.currentSponsors;
      return {
        kind: {
          case: "currentSponsors",
          value: {
            locale: optionalFromInput(locale),
            exhibitorsOnly,
            planId: planId === "" ? undefined : idFromInput(planId),
            status: BroadcastRecipientFilter_SponsorshipStatus[status],
          },
        },
      };
    }
    case "pastSponsors": {
      const { conferenceSlug, locale, status } = values.pastSponsors;
      return {
        kind: {
          case: "pastSponsors",
          value: {
            conferenceSlug,
            locale: optionalFromInput(locale),
            status: BroadcastRecipientFilter_SponsorshipStatus[status],
          },
        },
      };
    }
    case "manual":
      return {
        kind: {
          case: "manual",
          value: { sponsorshipIds: values.manual.sponsorshipIds.map(idFromInput) },
        },
      };
    case "raw":
      return { kind: { case: "raw", value: { emails: emailsFromInput(values.raw.emails) } } };
  }
}

const STANDING_TEXT: Readonly<Record<SponsorshipState, string>> = {
  [SponsorshipState.UNSPECIFIED]: "unknown",
  [SponsorshipState.PENDING]: "pending",
  [SponsorshipState.ACTIVE]: "accepted",
  [SponsorshipState.WITHDRAWN]: "withdrawn",
};

// What follows a picked sponsorship's name: its plan and where it stands.
export function sponsorshipDetailText(
  state: SponsorshipState,
  planName: string | undefined,
): string {
  const standing = STANDING_TEXT[state];
  return [planName ?? "no plan", standing].join(", ");
}

// Sponsorships in name order, which reads the same whatever the order the server answers in.
export function sortedByName<T extends { name: string }>(sponsorships: readonly T[]): T[] {
  return [...sponsorships].sort((a, b) => a.name.localeCompare(b.name));
}
