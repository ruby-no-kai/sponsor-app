import type { MessageInitShape } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import type { AdminConference } from "../../gen/rubykaigi/sponsor_app/admin_conference_pb.ts";
import type { ConferenceInputSchema } from "../../gen/rubykaigi/sponsor_app/admin_conferences_pb.ts";
import {
  optionalFromInput,
  optionalInt32FromInput,
  optionalToInput,
  timestampFromInput,
  timestampToInput,
} from "../../lib/forms.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";

// Named after ConferenceInput's JSON fields, so a google.rpc.BadRequest field path below "input."
// is the name of the form field it concerns.
export type ConferenceValues = {
  name: string;
  slug: string;
  contactEmailAddress: string;
  applicationOpensAt: string;
  applicationClosesAt: string;
  amendmentClosesAt: string;
  eventSubmissionStartsAt: string;
  ticketDistributionStartsAt: string;
  passRetractionDisablesAt: string;
  noPlanAllowed: boolean;
  boothCapacity: string;
  additionalAttendeesRegistrationOpen: boolean;
  hidden: boolean;
  allowRestrictedAccess: boolean;
  githubRepo: string;
  githubRepoImagesPath: string;
  titoSlug: string;
  titoBoothPaidFlatDiscountAmount: string;
};

// What the editor labels each field, in the order it lays them out.
export const FIELD_LABELS: Readonly<Record<keyof ConferenceValues, string>> = {
  name: "Name",
  slug: "Slug",
  contactEmailAddress: "Contact email address",
  applicationOpensAt: "Applications open",
  applicationClosesAt: "Applications close",
  amendmentClosesAt: "Amendments close",
  eventSubmissionStartsAt: "Event submission starts",
  ticketDistributionStartsAt: "Ticket distribution starts",
  passRetractionDisablesAt: "Pass retraction ends",
  noPlanAllowed: "Applications may leave the plan undecided",
  boothCapacity: "Booth capacity",
  additionalAttendeesRegistrationOpen: "Sponsors may request tickets beyond their plan's",
  hidden: "Hidden",
  allowRestrictedAccess: "Allow restricted staff",
  githubRepo: "GitHub repository",
  githubRepoImagesPath: "GitHub images path",
  titoSlug: "Ti.to event",
  titoBoothPaidFlatDiscountAmount: "Discount on paid booth staff tickets",
};

export const CONFERENCE_LAYOUT: FieldLayout = { labels: FIELD_LABELS };

export type DateTimeField = {
  name: keyof ConferenceValues & `${string}At`;
  description: string;
};

export const DATE_TIME_FIELDS: readonly DateTimeField[] = [
  {
    name: "applicationOpensAt",
    description: "Empty keeps applications closed.",
  },
  {
    name: "applicationClosesAt",
    description: "Empty keeps applications open once they have opened.",
  },
  {
    name: "amendmentClosesAt",
    description: "When sponsors can no longer edit their application. Empty sets no deadline.",
  },
  {
    name: "eventSubmissionStartsAt",
    description: "When accepted sponsors can submit their events. Empty keeps submission closed.",
  },
  {
    name: "ticketDistributionStartsAt",
    description: "When accepted sponsors can claim their tickets. Empty keeps them undistributed.",
  },
  {
    name: "passRetractionDisablesAt",
    description: "When sponsors can no longer void a redeemed pass. Empty keeps voiding available.",
  },
];

// A new conference starts with the defaults of the conferences table.
export function formValuesFrom(conference: AdminConference | undefined): ConferenceValues {
  const details = conference?.conference;
  return {
    name: details?.name ?? "",
    slug: details?.slug ?? "",
    contactEmailAddress: details?.contactEmailAddress ?? "",
    applicationOpensAt: timestampToInput(details?.applicationOpensAt),
    applicationClosesAt: timestampToInput(details?.applicationClosesAt),
    amendmentClosesAt: timestampToInput(details?.amendmentClosesAt),
    eventSubmissionStartsAt: timestampToInput(details?.eventSubmissionStartsAt),
    ticketDistributionStartsAt: timestampToInput(details?.ticketDistributionStartsAt),
    passRetractionDisablesAt: timestampToInput(details?.passRetractionDisablesAt),
    noPlanAllowed: details?.noPlanAllowed ?? true,
    boothCapacity: String(conference?.boothCapacity ?? 0),
    additionalAttendeesRegistrationOpen: details?.additionalAttendeesRegistrationOpen ?? false,
    hidden: conference?.hidden ?? false,
    allowRestrictedAccess: conference?.allowRestrictedAccess ?? false,
    githubRepo: optionalToInput(conference?.githubRepo),
    githubRepoImagesPath: optionalToInput(conference?.githubRepoImagesPath),
    titoSlug: optionalToInput(conference?.titoSlug),
    titoBoothPaidFlatDiscountAmount: conference?.titoBoothPaidFlatDiscountAmount ?? "0",
  };
}

export type ConferenceInputResult =
  | { kind: "ok"; input: MessageInitShape<typeof ConferenceInputSchema> }
  | { kind: "invalid"; fields: Record<string, string> };

// Every rule is the server's, which reports an emptied booth capacity as missing. Only a value the
// message cannot carry, such as 1.5 booths, is reported here, as it never reaches the server.
export function inputFrom(values: ConferenceValues): ConferenceInputResult {
  let boothCapacity: number | undefined;
  try {
    boothCapacity = optionalInt32FromInput(values.boothCapacity);
  } catch (error) {
    if (!(error instanceof RangeError)) throw error;
    return { kind: "invalid", fields: { boothCapacity: "Enter a whole number" } };
  }
  return {
    kind: "ok",
    input: {
      ...values,
      applicationOpensAt: timestampFromInput(values.applicationOpensAt),
      applicationClosesAt: timestampFromInput(values.applicationClosesAt),
      amendmentClosesAt: timestampFromInput(values.amendmentClosesAt),
      eventSubmissionStartsAt: timestampFromInput(values.eventSubmissionStartsAt),
      ticketDistributionStartsAt: timestampFromInput(values.ticketDistributionStartsAt),
      passRetractionDisablesAt: timestampFromInput(values.passRetractionDisablesAt),
      boothCapacity,
      githubRepo: optionalFromInput(values.githubRepo),
      githubRepoImagesPath: optionalFromInput(values.githubRepoImagesPath),
      titoSlug: optionalFromInput(values.titoSlug),
    },
  };
}

// The value a "Now" button puts into a datetime-local input, in the browser's time zone.
export function nowInput(now: Date = new Date()): string {
  return timestampToInput(timestampFromDate(now));
}
