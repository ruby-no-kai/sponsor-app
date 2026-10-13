import type { MessageInitShape } from "@bufbuild/protobuf";
import type {
  AdminBroadcast,
  BroadcastInputSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";

// Named after BroadcastInput's JSON fields, so a google.rpc.BadRequest field path below "input." is
// the name of the form field it concerns.
export type BroadcastValues = {
  campaign: string;
  description: string;
  title: string;
  body: string;
};

export type BroadcastInputInit = MessageInitShape<typeof BroadcastInputSchema>;

// What the editor labels each field, in the order it lays them out.
export const FIELD_LABELS = {
  campaign: "Campaign",
  description: "Description",
  title: "Title",
  body: "Body",
} as const satisfies Record<keyof BroadcastValues, string>;

export const BROADCAST_LAYOUT: FieldLayout = { labels: FIELD_LABELS };

export function broadcastValuesFrom(broadcast: AdminBroadcast | undefined): BroadcastValues {
  return {
    campaign: broadcast?.campaign ?? "",
    description: broadcast?.description ?? "",
    title: broadcast?.title ?? "",
    body: broadcast?.body ?? "",
  };
}

export function broadcastInputFrom(values: BroadcastValues): BroadcastInputInit {
  const { campaign, description, title, body } = values;
  return { campaign, description, title, body };
}
