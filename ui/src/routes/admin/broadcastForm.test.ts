import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toBinary } from "@bufbuild/protobuf";
import { Code, ConnectError } from "@connectrpc/connect";
import { BadRequestSchema } from "../../gen/google/rpc/error_details_pb.ts";
import { AdminBroadcastSchema } from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import { broadcastInputFrom, broadcastSaveErrors, broadcastValuesFrom } from "./broadcastForm.ts";

function invalidArgument(...fieldViolations: { field: string; description: string }[]) {
  const error = new ConnectError("invalid", Code.InvalidArgument);
  error.details.push({
    type: BadRequestSchema.typeName,
    value: toBinary(BadRequestSchema, create(BadRequestSchema, { fieldViolations })),
  });
  return error;
}

describe("broadcastValuesFrom", () => {
  it("starts a new broadcast empty, with no recipients chosen", () => {
    const values = broadcastValuesFrom(undefined);

    assert.deepEqual(broadcastInputFrom(values), {
      campaign: "",
      description: "",
      title: "",
      body: "",
    });
    assert.equal(values.recipientFilter.kind, "none");
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

describe("broadcastSaveErrors", () => {
  it("names the input's fields without their prefix and the recipient filter's as they are", () => {
    const error = invalidArgument(
      { field: "input.title", description: "value is required" },
      {
        field: "recipientFilter.raw.emails[1]",
        description: "value must be a valid email address",
      },
      { field: "conferenceSlug", description: "value does not match regex pattern" },
    );

    assert.deepEqual(broadcastSaveErrors(error), {
      form: "conferenceSlug: does not match regex pattern",
      fields: {
        title: "is required",
        "recipientFilter.raw.emails[1]": "must be a valid email address",
      },
    });
  });

  it("puts a problem without violations on the form", () => {
    const error = new ConnectError("The conference has none of the sponsorships 3.", Code.NotFound);

    assert.deepEqual(broadcastSaveErrors(error), {
      form: "The conference has none of the sponsorships 3.",
      fields: {},
    });
  });
});
