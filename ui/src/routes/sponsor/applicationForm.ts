import type { MessageInitShape } from "@bufbuild/protobuf";
import { Code, ConnectError } from "@connectrpc/connect";
import type { Conference } from "../../gen/rubykaigi/sponsor_app/conference_pb.ts";
import type { FallbackOption } from "../../gen/rubykaigi/sponsor_app/form_description_pb.ts";
import type {
  ApplicationPlan,
  SponsorshipApplication,
  SponsorshipApplication_BillingContact,
  SponsorshipApplication_Contact,
  SponsorshipInputSchema,
} from "../../gen/rubykaigi/sponsor_app/sponsor_applications_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import type { FormErrors } from "../../lib/errors.ts";
import {
  idFromInput,
  idToInput,
  optionalFromInput,
  optionalInt32FromInput,
  optionalInt32ToInput,
  optionalToInput,
} from "../../lib/forms.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";
import { FileTooLargeError, StorageError } from "../../lib/upload.ts";

// The "Other" choice among the plans: none determined yet.
export const OTHER_PLAN = "other";

export type ContactValues = {
  email: string;
  emailCc: string;
  address: string;
  organization: string;
  unit: string;
  name: string;
};

export type BillingContactValues = Omit<ContactValues, "emailCc">;

// The logo: a file record the application has or copies, a file chosen to upload, or none yet.
export type AssetChoice =
  | { kind: "none" }
  | { kind: "existing"; id: string }
  | { kind: "file"; file: File };

// Named after SponsorshipInput's JSON fields, so a google.rpc.BadRequest field path below
// "input.", such as "contact.email", is the name of the form field it concerns. The billing
// toggle and the acknowledgements are the form's own, and policyAgreement is the request's.
export type ApplicationValues = {
  // A plan ID, OTHER_PLAN, or "" while none is picked.
  planId: string;
  name: string;
  url: string;
  profile: string;
  boothRequested: boolean;
  fallbackOption: string;
  // A whole number, or "" for none.
  numberOfAdditionalAttendees: string;
  contact: ContactValues;
  specifiesBillingContact: boolean;
  alternateBillingContact: BillingContactValues;
  billingRequest: string;
  customizationRequest: string;
  note: string;
  assetFileId: AssetChoice;
  englishAcknowledged: boolean;
  zipAcknowledged: boolean;
  policyAgreement: boolean;
};

// The fields in the order the form lays them out, for ordering its errors.
const FIELD_ORDER = [
  "contact",
  "specifiesBillingContact",
  "alternateBillingContact",
  "billingRequest",
  "planId",
  "customizationRequest",
  "boothRequested",
  "fallbackOption",
  "name",
  "url",
  "profile",
  "englishAcknowledged",
  "assetFileId",
  "zipAcknowledged",
  "numberOfAdditionalAttendees",
  "note",
  "policyAgreement",
] as const;

export const APPLICATION_LAYOUT: FieldLayout = {
  labels: Object.fromEntries(FIELD_ORDER.map((name) => [name, name])),
};

// The texts each field is labelled with, by the first name of its path.
const FIELD_LABEL_KEYS: Readonly<Record<string, string>> = {
  contact: "sponsorships.form.contact",
  specifiesBillingContact: "sponsorships.form.specify_alternate_billing_contact",
  alternateBillingContact: "sponsor_ui.applications.billing_contact",
  billingRequest: "activerecord.attributes.sponsorship/billing_request.body",
  planId: "sponsorships.form.plan",
  customizationRequest: "activerecord.attributes.sponsorship/customization_request.body",
  boothRequested: "helpers.label.sponsorship.booth_requested",
  fallbackOption: "activerecord.attributes.sponsorship.fallback_option",
  name: "activerecord.attributes.sponsorship.name",
  url: "activerecord.attributes.sponsorship.url",
  profile: "activerecord.attributes.sponsorship.profile",
  englishAcknowledged: "sponsorships.form.warnings.english.header",
  assetFileId: "sponsorships.form.logo",
  zipAcknowledged: "sponsorships.form.warnings.zip_asset.header",
  numberOfAdditionalAttendees: "activerecord.attributes.sponsorship.number_of_additional_attendees",
  note: "activerecord.attributes.sponsorship/note.body",
  policyAgreement: "sponsorships.form.policies",
};

// The texts naming the field at a path, outermost first, such as the contact section's then its
// email's. Empty for a path the form has no field for.
export function fieldLabelKeys(path: string): string[] {
  const [head = "", child] = path.split(".");
  const key = FIELD_LABEL_KEYS[head];
  if (key === undefined) return [];
  if (child === undefined) return [key];
  const attribute = child.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);
  return [key, `activerecord.attributes.contact.${attribute}`];
}

function contactValues(contact: SponsorshipApplication_Contact | undefined): ContactValues {
  return {
    email: contact?.email ?? "",
    emailCc: optionalToInput(contact?.emailCc),
    address: contact?.address ?? "",
    organization: contact?.organization ?? "",
    unit: optionalToInput(contact?.unit),
    name: contact?.name ?? "",
  };
}

function billingContactValues(
  contact: SponsorshipApplication_BillingContact | undefined,
): BillingContactValues {
  return {
    email: contact?.email ?? "",
    address: contact?.address ?? "",
    organization: contact?.organization ?? "",
    unit: optionalToInput(contact?.unit),
    name: contact?.name ?? "",
  };
}

// The values a form starts from: a saved application's, a copied one's, or none. A saved
// application without a plan has picked "Other", while a new one has picked nothing yet.
export function formValuesFrom(
  application: SponsorshipApplication | undefined,
  { saved }: { saved: boolean },
): ApplicationValues {
  const planId = application?.planId;
  const assetFile = application?.assetFile;
  return {
    planId: planId !== undefined ? idToInput(planId) : saved ? OTHER_PLAN : "",
    name: application?.name ?? "",
    url: application?.url ?? "",
    profile: application?.profile ?? "",
    boothRequested: application?.boothRequested ?? false,
    fallbackOption: application?.fallbackOption ?? "",
    numberOfAdditionalAttendees: optionalInt32ToInput(application?.numberOfAdditionalAttendees),
    contact: contactValues(application?.contact),
    specifiesBillingContact: application?.alternateBillingContact !== undefined,
    alternateBillingContact: billingContactValues(application?.alternateBillingContact),
    billingRequest: application?.billingRequest ?? "",
    customizationRequest: application?.customizationRequest ?? "",
    note: application?.note ?? "",
    assetFileId:
      assetFile === undefined
        ? { kind: "none" }
        : { kind: "existing", id: idToInput(assetFile.id) },
    englishAcknowledged: false,
    zipAcknowledged: false,
    policyAgreement: false,
  };
}

// The values a form starts from, settled as the HAML form settles them on load: no booth request
// on a plan without a booth, and no fallback option the description lists but does not offer.
export function initialValues(
  application: SponsorshipApplication | undefined,
  {
    saved,
    plans,
    fallbackOptions,
  }: {
    saved: boolean;
    plans: readonly ApplicationPlan[];
    fallbackOptions: readonly FallbackOption[];
  },
): ApplicationValues {
  const loaded = formValuesFrom(application, { saved });
  const values = selectedPlan(plans, loaded.planId)?.boothEligible
    ? loaded
    : { ...loaded, boothRequested: false };
  // Without options the form has no field for one, so the saved value goes back unchanged.
  if (fallbackOptions.length === 0) return values;
  const offered = offeredFallbackOptions(fallbackOptions, fallbackSelectionOf(values, plans));
  return offered.some(({ value }) => value === values.fallbackOption)
    ? values
    : { ...values, fallbackOption: "" };
}

// Throws a RangeError for a numberOfAdditionalAttendees that is no whole number.
export function inputFrom(
  values: ApplicationValues,
  assetFileId: bigint | undefined,
): MessageInitShape<typeof SponsorshipInputSchema> {
  const { contact, alternateBillingContact: billing } = values;
  return {
    planId:
      values.planId === "" || values.planId === OTHER_PLAN ? undefined : idFromInput(values.planId),
    name: values.name,
    url: values.url,
    profile: values.profile,
    boothRequested: values.boothRequested,
    fallbackOption: values.fallbackOption,
    numberOfAdditionalAttendees: optionalInt32FromInput(values.numberOfAdditionalAttendees),
    contact: {
      ...contact,
      emailCc: optionalFromInput(contact.emailCc),
      unit: optionalFromInput(contact.unit),
    },
    alternateBillingContact: values.specifiesBillingContact
      ? { ...billing, unit: optionalFromInput(billing.unit) }
      : undefined,
    billingRequest: values.billingRequest,
    customizationRequest: values.customizationRequest,
    note: values.note,
    assetFileId,
  };
}

// The Rails page that redirects to a logo in the storage, under the conference it belongs to.
export function assetFileHref(conferenceSlug: string, assetFileId: bigint): string {
  return `/conferences/${encodeURIComponent(conferenceSlug)}/sponsorship_asset_files/${assetFileId}`;
}

export function selectedPlan(
  plans: readonly ApplicationPlan[],
  planId: string,
): ApplicationPlan | undefined {
  return plans.find((plan) => idToInput(plan.id) === planId);
}

// A plan that stopped taking applications stays selectable for an application that has it.
export function isPlanSelectable(plan: ApplicationPlan, savedPlanId: bigint | undefined): boolean {
  return plan.available || plan.id === savedPlanId;
}

// "Other" is offered where the conference allows no plan, or to an application saved with none.
export function offersOtherPlan(
  conference: Pick<Conference, "noPlanAllowed">,
  { saved, savedPlanId }: { saved: boolean; savedPlanId: bigint | undefined },
): boolean {
  return conference.noPlanAllowed || (saved && savedPlanId === undefined);
}

// Whether the booth request applies: a plan with a booth, at a conference offering booths.
export function boothApplies(
  conference: Pick<Conference, "boothsOffered">,
  plan: ApplicationPlan | undefined,
): boolean {
  return conference.boothsOffered && plan !== undefined && plan.boothEligible;
}

export type FallbackSelection = { planName: string | undefined; boothRequested: boolean };

export function fallbackSelectionOf(
  values: Pick<ApplicationValues, "planId" | "boothRequested">,
  plans: readonly ApplicationPlan[],
): FallbackSelection {
  return {
    planName: selectedPlan(plans, values.planId)?.name,
    boothRequested: values.boothRequested,
  };
}

// An option is offered when any of its conditions matches, and a condition matches when every
// part it sets does. An option without conditions is always offered.
export function isFallbackOptionOffered(
  option: FallbackOption,
  { planName, boothRequested }: FallbackSelection,
): boolean {
  if (option.conditions.length === 0) return true;
  return option.conditions.some(
    (condition) =>
      (condition.boothRequest === undefined || condition.boothRequest === boothRequested) &&
      (condition.plans.length === 0 ||
        (planName !== undefined && condition.plans.includes(planName))),
  );
}

// The options offered, one per value: options sharing a value differ only in when they apply.
export function offeredFallbackOptions(
  options: readonly FallbackOption[],
  selection: FallbackSelection,
): FallbackOption[] {
  const offered: FallbackOption[] = [];
  for (const option of options) {
    if (!isFallbackOptionOffered(option, selection)) continue;
    if (offered.some(({ value }) => value === option.value)) continue;
    offered.push(option);
  }
  return offered;
}

export type PriorityLabels = { withdraw: string; booth: string; noBooth: string };

// The plans the sponsor ends up with in order of preference, starting with the one applied for.
// `{plan}` stands for that plan, and `!booth`, `!no_booth` and `!withdraw` for what the labels say.
export function priorityItems(
  option: Pick<FallbackOption, "priorityHuman">,
  {
    planName,
    boothApplies,
    boothRequested,
  }: { planName: string | undefined; boothApplies: boolean; boothRequested: boolean },
  labels: PriorityLabels,
): string[] {
  const applied = boothApplies ? `{plan}!${boothRequested ? "booth" : "no_booth"}` : "{plan}";
  return [applied, ...option.priorityHuman].map((item) =>
    item
      .replace("{plan}", planName ?? "")
      .replaceAll("!no_booth", ` (${labels.noBooth})`)
      .replaceAll("!booth", ` (${labels.booth})`)
      .replaceAll("!withdraw", labels.withdraw),
  );
}

// Latin script plus the scripts and symbols shared across languages, as the organizers ask for
// the published listing in English.
const ENGLISH = /^[\p{Script=Latin}\p{Script=Zyyy}\p{Sc}\p{Sk}\p{Sm}\p{So}]*$/u;

export function looksNonEnglish(...texts: string[]): boolean {
  return texts.some((text) => !ENGLISH.test(text));
}

export function isZipFile(file: Pick<File, "name" | "type">): boolean {
  return (
    file.type === "application/zip" ||
    file.type === "application/x-zip-compressed" ||
    file.name.toLowerCase().endsWith(".zip")
  );
}

// The count a number input holds, or undefined when it holds none or no count an int32 holds.
function countFromInput(value: string): number | undefined {
  try {
    const count = optionalInt32FromInput(value);
    return count !== undefined && count >= 0 ? count : undefined;
  } catch (error) {
    if (!(error instanceof RangeError)) throw error;
    return undefined;
  }
}

// Conference tickets: those the plan includes, and with the additional ones asked for. An
// additional count that is no whole number counts as none.
export function ticketCounts(
  plan: ApplicationPlan | undefined,
  additional: string,
): { included: number; total: number } {
  const included = plan?.numberOfGuests ?? 0;
  return { included, total: included + (countFromInput(additional) ?? 0) };
}

export type ValidationMessages = {
  required: string;
  choosePlan: string;
  email: string;
  url: string;
  wholeNumber: string;
  chooseFile: string;
  acknowledge: string;
  agree: string;
};

export type ValidationContext = {
  creating: boolean;
  // Whether the form offers any fallback option for what is picked, which makes picking one
  // required.
  fallbackOffered: boolean;
};

const EMAIL = /^[^@\s]+@[^@\s]+$/;
const WEB_URL = /^https?:\/\/.+/;

// What the form checks before sending, as the HAML form's required fields and scripts do. The
// server checks everything again.
export function validateApplication(
  values: ApplicationValues,
  { creating, fallbackOffered }: ValidationContext,
  messages: ValidationMessages,
): FormErrors | undefined {
  const fields: Record<string, string> = {};
  const required = (path: string, value: string) => {
    if (value.trim() === "") fields[path] = messages.required;
  };
  const email = (path: string, value: string) => {
    required(path, value);
    if (fields[path] === undefined && !EMAIL.test(value.trim())) fields[path] = messages.email;
  };

  email("contact.email", values.contact.email);
  for (const name of ["address", "organization", "name"] as const) {
    required(`contact.${name}`, values.contact[name]);
  }
  if (values.specifiesBillingContact) {
    email("alternateBillingContact.email", values.alternateBillingContact.email);
    for (const name of ["address", "organization", "name"] as const) {
      required(`alternateBillingContact.${name}`, values.alternateBillingContact[name]);
    }
  }

  if (values.planId === "") fields.planId = messages.choosePlan;
  if (values.planId === OTHER_PLAN) required("customizationRequest", values.customizationRequest);
  if (fallbackOffered) required("fallbackOption", values.fallbackOption);

  required("name", values.name);
  required("url", values.url);
  if (fields.url === undefined && !WEB_URL.test(values.url.trim())) fields.url = messages.url;
  required("profile", values.profile);
  if (looksNonEnglish(values.name, values.profile) && !values.englishAcknowledged) {
    fields.englishAcknowledged = messages.acknowledge;
  }

  const asset = values.assetFileId;
  if (asset.kind === "none") fields.assetFileId = messages.chooseFile;
  if (asset.kind === "file" && isZipFile(asset.file) && !values.zipAcknowledged) {
    fields.zipAcknowledged = messages.acknowledge;
  }

  const additional = values.numberOfAdditionalAttendees;
  if (additional.trim() !== "" && countFromInput(additional) === undefined) {
    fields.numberOfAdditionalAttendees = messages.wholeNumber;
  }

  if (creating && !values.policyAgreement) fields.policyAgreement = messages.agree;

  return Object.keys(fields).length === 0 ? undefined : { fields };
}

// The server's violations of the Input, on the fields they concern.
export function saveErrors(error: unknown): FormErrors {
  return fieldViolations(error, { prefix: "input." });
}

export type UploadFailure =
  | { kind: "tooLarge"; maxSize: bigint }
  | { kind: "unsupportedType" }
  | { kind: "storage" }
  | { kind: "rpc"; error: ConnectError };

// Why a logo failed to upload, for the form to word in the sponsor's language. What the form
// sends the upload RPCs passes their other rules, so invalid_argument means a content type the
// server does not take: refused when the upload starts, or, when the browser could not tell it,
// once the storage holds the file.
export function uploadFailure(error: unknown): UploadFailure {
  if (error instanceof FileTooLargeError) return { kind: "tooLarge", maxSize: error.maxSize };
  if (error instanceof StorageError) return { kind: "storage" };
  const connectError = ConnectError.from(error);
  if (connectError.code === Code.InvalidArgument) return { kind: "unsupportedType" };
  return { kind: "rpc", error: connectError };
}
