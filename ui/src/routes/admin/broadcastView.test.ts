import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  AdminBroadcastDelivery_StatusSchema,
  AdminBroadcast_Status,
  AdminBroadcast_StatusSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import {
  BROADCAST_STATUS_LABELS,
  BUSY_POLL_INTERVAL_MS,
  DELIVERY_STATUS_LABELS,
  refreshIntervalFor,
} from "./broadcastView.ts";

describe("refreshIntervalFor", () => {
  it("polls while a job is at work on a broadcast", () => {
    for (const status of [
      AdminBroadcast_Status.CREATED,
      AdminBroadcast_Status.PREPARING,
      AdminBroadcast_Status.MODIFYING,
      AdminBroadcast_Status.PENDING,
      AdminBroadcast_Status.SENDING,
    ]) {
      assert.equal(refreshIntervalFor([AdminBroadcast_Status.SENT, status]), BUSY_POLL_INTERVAL_MS);
    }
  });

  it("stops once every broadcast rests", () => {
    assert.equal(
      refreshIntervalFor([
        AdminBroadcast_Status.READY,
        AdminBroadcast_Status.SENT,
        AdminBroadcast_Status.FAILED,
      ]),
      0,
    );
    assert.equal(refreshIntervalFor([]), 0);
  });
});

describe("status labels", () => {
  it("label every status the enums declare", () => {
    for (const { number } of AdminBroadcast_StatusSchema.values) {
      assert.ok(Object.hasOwn(BROADCAST_STATUS_LABELS, number), `broadcast status ${number}`);
    }
    for (const { number } of AdminBroadcastDelivery_StatusSchema.values) {
      assert.ok(Object.hasOwn(DELIVERY_STATUS_LABELS, number), `delivery status ${number}`);
    }
  });
});
