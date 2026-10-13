import type { BadgeVariant } from "@cloudflare/kumo";
import { generatePath } from "react-router";
import type { PassTicket } from "../../gen/rubykaigi/sponsor_app/sponsor_passes_pb.ts";
import { TitoDiscountCode_Kind } from "../../gen/rubykaigi/sponsor_app/tito_discount_code_pb.ts";
import { paths } from "../paths.ts";

// A badge's translation key, the text shown where the locale files lack it, and its colour.
export type BadgeLabel = { key: string; fallback: string; variant: BadgeVariant };

// The release slugs the organizers set up, in the HAML page's colours.
const RELEASE_VARIANTS: ReadonlyMap<string, BadgeVariant> = new Map([
  ["sponsor", "success"],
  ["exhibitor", "neutral"],
  ["exhibitor-paid", "warning"],
]);

const TICKET_STATE_VARIANTS: ReadonlyMap<string, BadgeVariant> = new Map([
  ["complete", "success"],
  ["incomplete", "warning"],
  ["unassigned", "neutral"],
]);

const INVITATION_KEYS: Readonly<Record<TitoDiscountCode_Kind, string>> = {
  [TitoDiscountCode_Kind.UNSPECIFIED]: "pass_redemptions.index.invitation.attendee_url",
  [TitoDiscountCode_Kind.ATTENDEE]: "pass_redemptions.index.invitation.attendee_url",
  [TitoDiscountCode_Kind.BOOTH_STAFF]: "pass_redemptions.index.invitation.booth_staff_url",
  [TitoDiscountCode_Kind.BOOTH_PAID]: "pass_redemptions.index.invitation.booth_paid_url",
};

export function releaseLabel(slug: string): BadgeLabel {
  return {
    key: `pass_redemptions.index.release_type.${slug}`,
    fallback: slug,
    variant: RELEASE_VARIANTS.get(slug) ?? "secondary",
  };
}

// A state the HAML page does not know shows as the ticketing service names it.
export function ticketStateLabel(ticket: Pick<PassTicket, "state" | "void">): BadgeLabel {
  if (ticket.void) {
    return { key: "pass_redemptions.index.state.void", fallback: "void", variant: "error" };
  }
  return {
    key: `pass_redemptions.index.state.${ticket.state}`,
    fallback: ticket.state,
    variant: TICKET_STATE_VARIANTS.get(ticket.state) ?? "info",
  };
}

// The label's text, or its fallback where the locale files lack the key, as t returns the key.
export function badgeText(t: (key: string) => string, label: BadgeLabel): string {
  const text = t(label.key);
  return text === label.key ? label.fallback : text;
}

export function invitationKey(kind: TitoDiscountCode_Kind): string {
  return INVITATION_KEYS[kind] ?? INVITATION_KEYS[TitoDiscountCode_Kind.ATTENDEE];
}

export function passRedemptionsPath(slug: string): string {
  return generatePath(paths.sponsorPassRedemptions, { slug });
}

// The retraction form, which HAML still renders.
export function newRetractionPath(slug: string, id: string): string {
  return `${passRedemptionsPath(slug)}/${encodeURIComponent(id)}/retraction/new`;
}
