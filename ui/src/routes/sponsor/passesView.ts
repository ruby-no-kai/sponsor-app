import { getOption, isFieldSet } from "@bufbuild/protobuf";
import type { DescField, MessageInitShape } from "@bufbuild/protobuf";
import type { BadgeVariant } from "@cloudflare/kumo";
import { generatePath } from "react-router";
import { StringRulesSchema, field } from "../../gen/buf/validate/validate_pb.ts";
import type { StringRules } from "../../gen/buf/validate/validate_pb.ts";
import {
  PassRetractionInputSchema,
  PassRetraction_State,
  SponsorServiceGetPassRetractionRequestSchema,
} from "../../gen/rubykaigi/sponsor_app/sponsor_passes_pb.ts";
import type {
  PassRetraction,
  PassTicket,
} from "../../gen/rubykaigi/sponsor_app/sponsor_passes_pb.ts";
import { TitoDiscountCode_Kind } from "../../gen/rubykaigi/sponsor_app/tito_discount_code_pb.ts";
import type { FormErrors } from "../../lib/errors.ts";
import type { Vars } from "../../lib/translations.ts";
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

export function retractionPath(slug: string, id: string): string {
  return generatePath(paths.sponsorPassRetraction, { slug, id });
}

export function newRetractionPath(slug: string, id: string): string {
  return generatePath(paths.sponsorPassRetractionNew, { slug, id });
}

// The buf.validate rules on a string field, which the checks before sending follow.
function stringRulesOf(desc: DescField): StringRules | undefined {
  const rules = getOption(desc, field);
  return rules.type.case === "string" ? rules.type.value : undefined;
}

const REGISTRATION_ID = new RegExp(
  stringRulesOf(SponsorServiceGetPassRetractionRequestSchema.field.titoRegistrationId)?.pattern ??
    "",
);

// Whether GetPassRetraction takes the ID, rather than answer invalid_argument.
export function isRegistrationId(id: string): boolean {
  return id !== "" && REGISTRATION_ID.test(id);
}

// How often the retraction page asks again while the ticketing service has yet to void it.
export function retractionRefreshInterval(state: PassRetraction_State | undefined): number {
  return state === PassRetraction_State.PENDING ? 3000 : 0;
}

export type RetractionValues = { reason: string; confirmed: boolean };

// Starts from the reason a failed request left stored, but never from a confirmation.
export function retractionValuesFrom(retraction: Pick<PassRetraction, "reason">): RetractionValues {
  return { reason: retraction.reason ?? "", confirmed: false };
}

const REASON_RULES = stringRulesOf(PassRetractionInputSchema.field.reason);

// In characters, not UTF-16 units, as buf.validate counts.
export const REASON_MAX_LENGTH: number =
  REASON_RULES !== undefined && isFieldSet(REASON_RULES, StringRulesSchema.field.maxLen)
    ? Number(REASON_RULES.maxLen)
    : Number.POSITIVE_INFINITY;

type Translator = (key: string, vars?: Vars) => string;

// The checks the server would fail the reason on, worded through t.
export function reasonError(reason: string, t: Translator): string | undefined {
  if (reason.trim() === "") return t("sponsor_ui.passes.reason_required");
  if ([...reason].length > REASON_MAX_LENGTH) {
    return t("sponsor_ui.passes.reason_too_long", { count: REASON_MAX_LENGTH });
  }
  return undefined;
}

export function confirmationError(confirmed: boolean, t: Translator): string | undefined {
  return confirmed ? undefined : t("sponsor_ui.passes.confirmation_required");
}

// The checks the server would fail the form on, run before sending it.
export function retractionErrors(values: RetractionValues, t: Translator): FormErrors | undefined {
  const fields: Record<string, string> = {};
  const reason = reasonError(values.reason, t);
  if (reason !== undefined) fields["reason"] = reason;
  const confirmed = confirmationError(values.confirmed, t);
  if (confirmed !== undefined) fields["confirmed"] = confirmed;
  return Object.keys(fields).length === 0 ? undefined : { fields };
}

export function retractionInputFrom(
  values: RetractionValues,
): MessageInitShape<typeof PassRetractionInputSchema> {
  return { reason: values.reason, confirmed: values.confirmed };
}
