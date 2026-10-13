import {
  AdminBroadcastDelivery_Status,
  AdminBroadcast_Status,
} from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import type { Label } from "./sponsorshipView.ts";

export const BROADCAST_STATUS_LABELS: Readonly<Record<AdminBroadcast_Status, Label>> = {
  [AdminBroadcast_Status.UNSPECIFIED]: { text: "unknown", tone: "outline" },
  [AdminBroadcast_Status.CREATED]: { text: "created", tone: "warning" },
  [AdminBroadcast_Status.PREPARING]: { text: "preparing", tone: "warning" },
  [AdminBroadcast_Status.MODIFYING]: { text: "modifying", tone: "warning" },
  [AdminBroadcast_Status.READY]: { text: "ready", tone: "info" },
  [AdminBroadcast_Status.PENDING]: { text: "pending", tone: "warning" },
  [AdminBroadcast_Status.SENDING]: { text: "sending", tone: "warning" },
  [AdminBroadcast_Status.SENT]: { text: "sent", tone: "success" },
  [AdminBroadcast_Status.FAILED]: { text: "failed", tone: "error" },
};

export const DELIVERY_STATUS_LABELS: Readonly<Record<AdminBroadcastDelivery_Status, Label>> = {
  [AdminBroadcastDelivery_Status.UNSPECIFIED]: { text: "unknown", tone: "outline" },
  [AdminBroadcastDelivery_Status.CREATED]: { text: "created", tone: "warning" },
  [AdminBroadcastDelivery_Status.PREPARING]: { text: "preparing", tone: "warning" },
  [AdminBroadcastDelivery_Status.READY]: { text: "ready", tone: "outline" },
  [AdminBroadcastDelivery_Status.PENDING]: { text: "pending", tone: "warning" },
  [AdminBroadcastDelivery_Status.SENDING]: { text: "sending", tone: "warning" },
  [AdminBroadcastDelivery_Status.SENT]: { text: "sent", tone: "info" },
  [AdminBroadcastDelivery_Status.FAILED]: { text: "failed", tone: "error" },
  [AdminBroadcastDelivery_Status.REJECTED]: { text: "rejected", tone: "error" },
  [AdminBroadcastDelivery_Status.ACCEPTED]: { text: "accepted", tone: "info" },
  [AdminBroadcastDelivery_Status.DELIVERED]: { text: "delivered", tone: "info" },
  [AdminBroadcastDelivery_Status.OPENED]: { text: "opened", tone: "success" },
  [AdminBroadcastDelivery_Status.CLICKED]: { text: "clicked", tone: "success" },
};

// The states a background job moves the broadcast out of on its own.
const BUSY_STATUSES: ReadonlySet<AdminBroadcast_Status> = new Set([
  AdminBroadcast_Status.CREATED,
  AdminBroadcast_Status.PREPARING,
  AdminBroadcast_Status.MODIFYING,
  AdminBroadcast_Status.PENDING,
  AdminBroadcast_Status.SENDING,
]);

export function isBusy(status: AdminBroadcast_Status): boolean {
  return BUSY_STATUSES.has(status);
}

export const BUSY_POLL_INTERVAL_MS = 2000;

// For SWR's refreshInterval: polls while a job is at work on any of the broadcasts.
export function refreshIntervalFor(statuses: readonly AdminBroadcast_Status[]): number {
  return statuses.some(isBusy) ? BUSY_POLL_INTERVAL_MS : 0;
}
