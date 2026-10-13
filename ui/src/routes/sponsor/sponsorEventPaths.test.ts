import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { isSpaPathname } from "../paths.ts";
import { exhibitionEditPath, exhibitionNewPath } from "./sponsorEventPaths.ts";

describe("paths", () => {
  it("builds the pages the SPA renders", () => {
    for (const path of [exhibitionNewPath("rubykaigi2048"), exhibitionEditPath("rubykaigi2048")]) {
      assert.ok(isSpaPathname(path), path);
    }
  });
});
