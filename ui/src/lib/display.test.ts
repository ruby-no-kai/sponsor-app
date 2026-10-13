import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { formatAmount, isWebUrl } from "./display.ts";

describe("isWebUrl", () => {
  it("accepts http and https only", () => {
    assert.ok(isWebUrl("https://example.invalid/"));
    assert.ok(isWebUrl("http://example.invalid/"));
    assert.ok(!isWebUrl("javascript:alert(1)"));
    assert.ok(!isWebUrl("example.invalid"));
  });
});

describe("formatAmount", () => {
  it("groups thousands and drops a zero fraction", () => {
    assert.equal(formatAmount("1200000.0"), "1,200,000");
    assert.equal(formatAmount("1234.5"), "1,234.5");
    assert.equal(formatAmount("0.0"), "0");
  });

  it("keeps the sign of a negative amount apart from the groups", () => {
    assert.equal(formatAmount("-100000"), "-100,000");
    assert.equal(formatAmount("-999"), "-999");
  });
});
