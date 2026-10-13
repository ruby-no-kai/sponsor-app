import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { isAllowedFile } from "./upload.ts";

describe("isAllowedFile", () => {
  it("takes the types the server takes", () => {
    assert.ok(isAllowedFile({ type: "image/webp" }));
    assert.ok(!isAllowedFile({ type: "text/html" }));
    assert.ok(!isAllowedFile({ type: "" }));
  });
});
