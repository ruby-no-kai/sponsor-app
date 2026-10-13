import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toBinary } from "@bufbuild/protobuf";
import { Code, ConnectError } from "@connectrpc/connect";
import { BadRequestSchema } from "../gen/google/rpc/error_details_pb.ts";
import { fieldViolations } from "./errors.ts";
import {
  erroredFields,
  errorsAt,
  errorsUnder,
  fieldLabel,
  messagesAt,
  parentPath,
} from "./fieldErrors.ts";

describe("parentPath", () => {
  it("steps up one segment at a time", () => {
    assert.equal(parentPath("fallbackOptions[1].conditions[0]"), "fallbackOptions[1].conditions");
    assert.equal(parentPath("fallbackOptions[1].conditions"), "fallbackOptions[1]");
    assert.equal(parentPath("fallbackOptions[1]"), "fallbackOptions");
    assert.equal(parentPath("fallbackOptions"), undefined);
  });
});

describe("a layout without lists", () => {
  const layout = {
    labels: { contact: "Contact", email: "Email", name: "Name", plan: "Plan" },
  };

  it("labels a nested field under its parent", () => {
    assert.equal(fieldLabel("contact.email", layout), "Contact › Email");
  });

  it("orders errored fields as laid out, and fields it does not lay out last", () => {
    const fields = erroredFields(
      {
        unknown: { errors: ["is unknown"] },
        plan: { errors: ["is required"] },
        "contact.name": { errors: ["is required"] },
        "contact.email": { errors: ["is not an email address"] },
      },
      layout,
    );

    assert.deepEqual(
      fields.map(({ path }) => path),
      ["contact.email", "contact.name", "plan", "unknown"],
    );
  });
});

describe("errorsAt", () => {
  // As TanStack Form holds the errors fieldViolations returned, under the field names.
  function metasFor(...violations: { field: string; description: string }[]) {
    const error = new ConnectError("invalid", Code.InvalidArgument);
    error.details.push({
      type: BadRequestSchema.typeName,
      value: toBinary(BadRequestSchema, create(BadRequestSchema, { fieldViolations: violations })),
    });
    const { fields } = fieldViolations(error, { prefix: "input." });
    return Object.fromEntries(
      Object.entries(fields).map(([name, message]) => [name, { errors: [message] }]),
    );
  }

  it("finds a violation at a nested field path", () => {
    const metas = metasFor({
      field: "input.fallbackOptions[1].value",
      description: "value is required",
    });

    assert.deepEqual(errorsAt(metas, "fallbackOptions[1].value"), ["is required"]);
    assert.deepEqual(errorsAt(metas, "fallbackOptions[0].value"), []);
  });

  it("finds a message-level violation on a list element", () => {
    const metas = metasFor({
      field: "input.fallbackOptions[0].conditions[1]",
      description: "a condition must name plans or a booth request",
    });

    assert.deepEqual(errorsAt(metas, "fallbackOptions[0].conditions[1]"), [
      "a condition must name plans or a booth request",
    ]);
  });

  it("numbers the violations of list items when asked", () => {
    const metas = metasFor(
      { field: "input.fallbackOptions[0].priorityHuman", description: "too many" },
      { field: "input.fallbackOptions[0].priorityHuman[1]", description: "too long" },
      { field: "input.fallbackOptions[0].priorityHumanNote", description: "unrelated" },
    );

    assert.deepEqual(errorsAt(metas, "fallbackOptions[0].priorityHuman", { items: true }), [
      "too many",
      "#2: too long",
    ]);
    assert.deepEqual(errorsAt(metas, "fallbackOptions[0].priorityHuman"), ["too many"]);
  });
});

describe("errorsUnder", () => {
  it("collects the errors at and below a path by the rest of their path", () => {
    const fieldMeta = {
      recipientFilter: { errors: ["is required"] },
      "recipientFilter.raw.emails[1]": { errors: ["value must be a valid email address", 1] },
      "recipientFilter.raw.emails": { errors: [] },
      recipientFilterExtra: { errors: ["elsewhere"] },
      campaign: { errors: ["is required"] },
    };

    assert.deepEqual(errorsUnder(fieldMeta, "recipientFilter"), {
      "": ["is required"],
      "raw.emails[1]": ["value must be a valid email address"],
    });
  });
});

describe("messagesAt", () => {
  it("leads each element's messages with the element, after the list's own", () => {
    const errors = {
      "raw.emails": ["repeated value must contain unique items"],
      "raw.emails[1]": ["value must be a valid email address"],
      "raw.emails[7]": ["value is too long"],
      "raw.emailsExtra[0]": ["elsewhere"],
      "raw.emails[]": ["malformed"],
    };

    assert.deepEqual(messagesAt(errors, "raw.emails", ["a@example.invalid", "nope"]), [
      "repeated value must contain unique items",
      "nope: value must be a valid email address",
      "#8: value is too long",
    ]);
  });
});
