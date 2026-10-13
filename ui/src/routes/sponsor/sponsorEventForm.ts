import type { MessageInitShape } from "@bufbuild/protobuf";
import type {
  SponsorEvent,
  SponsorEventInputSchema,
} from "../../gen/rubykaigi/sponsor_app/sponsor_events_pb.ts";
import type { FormErrors } from "../../lib/errors.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";
import { idToInput, venueTimeFromInput, venueTimeToInput } from "../../lib/forms.ts";
import { looksNonEnglish } from "./applicationForm.ts";

// The event's image: one the event has, a file chosen to upload, or none.
export type EventImage =
  | { kind: "none" }
  | { kind: "existing"; id: string }
  | { kind: "file"; file: File };

// Named after SponsorEventInput's JSON fields, so a google.rpc.BadRequest field path below
// "input." is the name of the form field it concerns. The acknowledgement is the form's own, and
// policyAgreement is the request's.
export type SponsorEventValues = {
  title: string;
  startsAt: string;
  url: string;
  price: string;
  capacity: string;
  locationEn: string;
  locationLocal: string;
  assetFileId: EventImage;
  englishAcknowledged: boolean;
  policyAgreement: boolean;
};

// The fields that must read as English, checked together as the HAML form's script does.
export const ENGLISH_FIELDS = ["title", "price", "capacity", "locationEn"] as const;

// Translation keys of the labels, by field, in the order the form lays them out.
export const FIELD_LABEL_KEYS: Readonly<Record<string, string>> = {
  title: "activerecord.attributes.sponsor_event.title",
  startsAt: "activerecord.attributes.sponsor_event.starts_at",
  url: "activerecord.attributes.sponsor_event.url",
  price: "activerecord.attributes.sponsor_event.price",
  capacity: "activerecord.attributes.sponsor_event.capacity",
  locationEn: "activerecord.attributes.sponsor_event.location_en",
  locationLocal: "activerecord.attributes.sponsor_event.location_local",
  assetFileId: "sponsor_events.form.asset_file",
  englishAcknowledged: "views.sponsor_events.warnings.english.header",
  policyAgreement: "activerecord.attributes.sponsor_event.policy_agreement",
};

// Labels are translation keys here, resolved where the form has the translator.
export const SPONSOR_EVENT_LAYOUT: FieldLayout = { labels: FIELD_LABEL_KEYS };

// The input's value to the minute, as the field takes no seconds.
export function minuteInput(value: string): string {
  return value.slice(0, "YYYY-MM-DDTHH:MM".length);
}

export function eventValuesFrom(event: SponsorEvent | undefined): SponsorEventValues {
  return {
    title: event?.title ?? "",
    startsAt: minuteInput(venueTimeToInput(event?.startsAt)),
    url: event?.url ?? "",
    price: event?.price ?? "",
    capacity: event?.capacity ?? "",
    locationEn: event?.locationEn ?? "",
    locationLocal: event?.locationLocal ?? "",
    assetFileId:
      event?.assetFile === undefined
        ? { kind: "none" }
        : { kind: "existing", id: idToInput(event.assetFile.id) },
    englishAcknowledged: false,
    // An event already saved was agreed to when it was submitted.
    policyAgreement: event !== undefined,
  };
}

// Whether any field that must be English holds other text.
export function needsEnglishAcknowledgement(values: SponsorEventValues): boolean {
  return looksNonEnglish(...ENGLISH_FIELDS.map((name) => values[name]));
}

export type ValidationMessages = {
  required: string;
  url: string;
  datetime: string;
  acknowledge: string;
  agree: string;
};

const WEB_URL = /^https?:\/\/.+/;

// What the form checks before sending, as the HAML form's required fields and script do. The
// server checks everything again.
export function validateEvent(
  values: SponsorEventValues,
  { creating }: { creating: boolean },
  messages: ValidationMessages,
): FormErrors | undefined {
  const fields: Record<string, string> = {};
  if (values.title.trim() === "") fields.title = messages.required;

  if (values.startsAt === "") {
    fields.startsAt = messages.required;
  } else {
    try {
      venueTimeFromInput(values.startsAt);
    } catch (error) {
      if (!(error instanceof RangeError)) throw error;
      fields.startsAt = messages.datetime;
    }
  }

  if (values.url.trim() === "") fields.url = messages.required;
  else if (!WEB_URL.test(values.url.trim())) fields.url = messages.url;

  if (needsEnglishAcknowledgement(values) && !values.englishAcknowledged) {
    fields.englishAcknowledged = messages.acknowledge;
  }
  if (creating && !values.policyAgreement) fields.policyAgreement = messages.agree;

  return Object.keys(fields).length === 0 ? undefined : { fields };
}

// The Input for the values, with the ID of the image once it is uploaded. Absent removes the image.
// Throws RangeError for a start the message cannot carry, which validateEvent reports first.
export function eventInputFrom(
  values: SponsorEventValues,
  assetFileId: bigint | undefined,
): MessageInitShape<typeof SponsorEventInputSchema> {
  return {
    title: values.title,
    startsAt: venueTimeFromInput(values.startsAt),
    url: values.url,
    price: values.price,
    capacity: values.capacity,
    locationEn: values.locationEn,
    locationLocal: values.locationLocal,
    assetFileId,
  };
}

// The Rails page redirecting to an event's image in the storage.
export function eventImageHref(conferenceSlug: string, assetFileId: bigint): string {
  return `/conferences/${encodeURIComponent(conferenceSlug)}/event_asset_files/${assetFileId}`;
}
