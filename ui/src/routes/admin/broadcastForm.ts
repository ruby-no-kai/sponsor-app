import type { MessageInitShape } from "@bufbuild/protobuf";
import type {
  AdminBroadcast,
  BroadcastInputSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import type { FormErrors } from "../../lib/errors.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";
import { RECIPIENT_FILTER_LABELS, recipientFilterValues } from "./recipientFilterForm.ts";
import type { RecipientFilterValues } from "./recipientFilterForm.ts";

// Named after BroadcastInput's JSON fields, so a google.rpc.BadRequest field path below "input." is
// the name of the form field it concerns. The recipient filter goes with a new broadcast only.
export type BroadcastValues = {
  campaign: string;
  description: string;
  title: string;
  body: string;
  recipientFilter: RecipientFilterValues;
};

export type BroadcastInputInit = MessageInitShape<typeof BroadcastInputSchema>;

// What the editor labels each field, in the order it lays them out.
export const FIELD_LABELS = {
  campaign: "Campaign",
  description: "Description",
  title: "Title",
  body: "Body",
} as const satisfies Record<Exclude<keyof BroadcastValues, "recipientFilter">, string>;

export const BROADCAST_LAYOUT: FieldLayout = {
  labels: { ...FIELD_LABELS, ...RECIPIENT_FILTER_LABELS },
};

// A new broadcast adds no recipients until a filter is chosen, as the HAML form does.
export function broadcastValuesFrom(broadcast: AdminBroadcast | undefined): BroadcastValues {
  return {
    campaign: broadcast?.campaign ?? "",
    description: broadcast?.description ?? "",
    title: broadcast?.title ?? "",
    body: broadcast?.body ?? "",
    recipientFilter: recipientFilterValues("none"),
  };
}

export function broadcastInputFrom(values: BroadcastValues): BroadcastInputInit {
  const { campaign, description, title, body } = values;
  return { campaign, description, title, body };
}

// A save's violations by editor field: the input's without their "input." prefix, the recipient
// filter's as they are. Any other becomes the form-level message.
export function broadcastSaveErrors(error: unknown): FormErrors {
  const { form, fields } = fieldViolations(error);
  const messages = form === undefined ? [] : [form];
  const mapped: Record<string, string> = {};
  for (const [path, message] of Object.entries(fields)) {
    if (path.startsWith("input.")) {
      mapped[path.slice("input.".length)] = message;
    } else if (path === "recipientFilter" || path.startsWith("recipientFilter.")) {
      mapped[path] = message;
    } else {
      messages.push(`${path}: ${message}`);
    }
  }
  return messages.length === 0 ? { fields: mapped } : { form: messages.join("; "), fields: mapped };
}
