import type { MessageInitShape } from "@bufbuild/protobuf";
import type {
  AdminSponsorship,
  AdminSponsorship_Contact,
  AdminSponsorship_Plan,
} from "../../gen/rubykaigi/sponsor_app/admin_sponsorship_pb.ts";
import type { AdminSponsorshipInputSchema } from "../../gen/rubykaigi/sponsor_app/admin_sponsorships_pb.ts";
import type { FallbackOption } from "../../gen/rubykaigi/sponsor_app/form_description_pb.ts";
import {
  idFromInput,
  idToInput,
  optionalFromInput,
  optionalInt32FromInput,
  optionalInt32ToInput,
  optionalToInput,
} from "../../lib/forms.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";

export type ContactValues = {
  email: string;
  emailCc: string;
  address: string;
  organization: string;
  unit: string;
  name: string;
};

export type BillingContactValues = Omit<ContactValues, "emailCc">;

// Named after AdminSponsorshipInput's JSON fields, so a google.rpc.BadRequest field path below
// "input.", such as "contact.email", is the name of the form field it concerns. The one exception
// is specifiesBillingContact, the toggle that decides whether alternateBillingContact is sent.
export type SponsorshipValues = {
  // A plan ID, or "" for none.
  planId: string;
  name: string;
  url: string;
  profile: string;
  boothRequested: boolean;
  boothAssigned: boolean;
  fallbackOption: string;
  customization: boolean;
  customizationName: string;
  suspended: boolean;
  accepted: boolean;
  // A whole number, or "" for none.
  numberOfAdditionalAttendees: string;
  contact: ContactValues;
  specifiesBillingContact: boolean;
  alternateBillingContact: BillingContactValues;
  customizationRequest: string;
  billingRequest: string;
  note: string;
};

// What the editor labels each field, by the last name of its path, in the order it lays them out.
// A contact's name orders as the sponsorship's, whose label it shares.
export const FIELD_LABELS = {
  contact: "Contact",
  email: "Email",
  emailCc: "Email CC",
  organization: "Organization",
  unit: "Unit",
  address: "Address",
  specifiesBillingContact: "Specify an alternate billing contact",
  alternateBillingContact: "Billing contact",
  billingRequest: "Billing request",
  planId: "Plan",
  customizationRequest: "Customization request",
  customization: "Customization confirmed",
  customizationName: "Customization name",
  boothRequested: "Booth requested",
  boothAssigned: "Booth assigned",
  fallbackOption: "Fallback option",
  name: "Name",
  url: "URL",
  profile: "Profile",
  note: "Note",
  numberOfAdditionalAttendees: "Additional attendees",
  accepted: "Accepted",
  suspended: "Suspended",
} as const;

export const SPONSORSHIP_LAYOUT: FieldLayout = { labels: FIELD_LABELS };

function contactValues(contact: AdminSponsorship_Contact | undefined): ContactValues {
  return {
    email: contact?.email ?? "",
    emailCc: optionalToInput(contact?.emailCc),
    address: contact?.address ?? "",
    organization: contact?.organization ?? "",
    unit: optionalToInput(contact?.unit),
    name: contact?.name ?? "",
  };
}

export function formValuesFrom(sponsorship: AdminSponsorship): SponsorshipValues {
  const { emailCc: _emailCc, ...billingContact } = contactValues(
    sponsorship.alternateBillingContact,
  );
  return {
    planId: sponsorship.plan === undefined ? "" : idToInput(sponsorship.plan.id),
    name: sponsorship.name,
    url: sponsorship.url,
    profile: sponsorship.profile,
    boothRequested: sponsorship.boothRequested,
    boothAssigned: sponsorship.boothAssigned,
    fallbackOption: sponsorship.fallbackOption,
    customization: sponsorship.customization,
    customizationName: optionalToInput(sponsorship.customizationName),
    suspended: sponsorship.suspended,
    accepted: sponsorship.acceptedAt !== undefined,
    numberOfAdditionalAttendees: optionalInt32ToInput(sponsorship.numberOfAdditionalAttendees),
    contact: contactValues(sponsorship.contact),
    specifiesBillingContact: sponsorship.alternateBillingContact !== undefined,
    alternateBillingContact: billingContact,
    customizationRequest: sponsorship.customizationRequest,
    billingRequest: sponsorship.billingRequest,
    note: sponsorship.note,
  };
}

// Throws a RangeError for a numberOfAdditionalAttendees that is no whole number. Empty optional
// strings are unset, so a column that holds null keeps it.
export function inputFrom(
  values: SponsorshipValues,
): MessageInitShape<typeof AdminSponsorshipInputSchema> {
  const {
    planId,
    numberOfAdditionalAttendees,
    specifiesBillingContact,
    alternateBillingContact,
    contact,
    customizationName,
    ...fields
  } = values;
  return {
    ...fields,
    planId: planId === "" ? undefined : idFromInput(planId),
    numberOfAdditionalAttendees: optionalInt32FromInput(numberOfAdditionalAttendees),
    customizationName: optionalFromInput(customizationName),
    contact: {
      ...contact,
      emailCc: optionalFromInput(contact.emailCc),
      unit: optionalFromInput(contact.unit),
    },
    alternateBillingContact: specifiesBillingContact
      ? { ...alternateBillingContact, unit: optionalFromInput(alternateBillingContact.unit) }
      : undefined,
  };
}

// What a plan comes with, as the HAML form lists it beside the plan's name.
export function planTerms(plan: AdminSponsorship_Plan): string {
  const guests = plan.numberOfGuests === 1 ? "1 guest" : `${plan.numberOfGuests} guests`;
  const terms = [plan.priceText, guests];
  if (plan.boothSize > 0) terms.push(`booth size ${plan.boothSize}`);
  if (plan.talkable) terms.push("Talk");
  return terms.filter((term) => term !== "").join(", ");
}

export type SelectItem = { label: string; value: string };

// The form's fallback options, one per value as options sharing one differ only in when the form
// offers them. The sponsorship's own value follows when the form no longer offers it, so saving
// keeps it rather than dropping it unseen.
export function fallbackOptionItems(
  choices: readonly FallbackOption[],
  current: string,
): SelectItem[] {
  const items: SelectItem[] = [{ label: "(none)", value: "" }];
  for (const { name, value } of choices) {
    if (!items.some((item) => item.value === value)) items.push({ label: name, value });
  }
  if (!items.some((item) => item.value === current)) {
    items.push({ label: `${current} (not offered by the form)`, value: current });
  }
  return items;
}

// Words in a profile, counted as Sponsorship#word_count counts them against the plan's limit.
export function wordCount(text: string): number {
  return text.match(/[\w\-'’]+/g)?.length ?? 0;
}
