import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { erroredFields, fieldLabel, parentPath } from "./fieldErrors.ts";

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
