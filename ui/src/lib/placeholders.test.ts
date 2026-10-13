import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { markPlaceholders } from "./placeholders.ts";

describe("markPlaceholders", () => {
  it("marks a token in text", () => {
    assert.equal(
      markPlaceholders("<p>Sign in: @LOGIN@</p>", ["@LOGIN@"]),
      "<p>Sign in: <mark>@LOGIN@</mark></p>",
    );
  });

  it("leaves a token inside a tag's attribute alone", () => {
    assert.equal(
      markPlaceholders('<a href="@LOGIN@">@LOGIN@</a>', ["@LOGIN@"]),
      '<a href="@LOGIN@"><mark>@LOGIN@</mark></a>',
    );
  });

  it("changes nothing without tokens", () => {
    assert.equal(markPlaceholders("<p>@LOGIN@</p>", []), "<p>@LOGIN@</p>");
  });
});
