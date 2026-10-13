import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import { AdminBroadcastSchema } from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import { broadcastInputFrom, broadcastValuesFrom } from "./broadcastForm.ts";

describe("broadcastValuesFrom", () => {
  it("starts a new broadcast empty", () => {
    assert.deepEqual(broadcastInputFrom(broadcastValuesFrom(undefined)), {
      campaign: "",
      description: "",
      title: "",
      body: "",
    });
  });

  it("round-trips a saved broadcast's writable fields", () => {
    const broadcast = create(AdminBroadcastSchema, {
      id: 7n,
      campaign: "cfp",
      description: "Reminder",
      title: "CFP closes soon",
      body: "Hello @LOGIN@",
      bodyHtml: "<p>Hello @LOGIN@</p>",
    });

    assert.deepEqual(broadcastInputFrom(broadcastValuesFrom(broadcast)), {
      campaign: "cfp",
      description: "Reminder",
      title: "CFP closes soon",
      body: "Hello @LOGIN@",
    });
  });
});
