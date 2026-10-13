import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { isSpaPathname } from "../paths.ts";
import {
  eventEditPath,
  eventIdFromParam,
  eventNewPath,
  eventPath,
  exhibitionEditPath,
  exhibitionNewPath,
} from "./sponsorEventPaths.ts";

describe("paths", () => {
  it("builds the pages the SPA renders", () => {
    for (const path of [
      eventNewPath("rubykaigi2048"),
      eventPath("rubykaigi2048", 5n),
      eventEditPath("rubykaigi2048", "5"),
      exhibitionNewPath("rubykaigi2048"),
      exhibitionEditPath("rubykaigi2048"),
    ]) {
      assert.ok(isSpaPathname(path), path);
    }
    assert.equal(
      eventEditPath("rubykaigi2048", 5n),
      "/conferences/rubykaigi2048/sponsorship/events/5/edit",
    );
  });

  it("leaves the image download to Rails", () => {
    assert.ok(!isSpaPathname("/conferences/rubykaigi2048/event_asset_files/9"));
  });
});

describe("eventIdFromParam", () => {
  it("reads an ID", () => {
    assert.equal(eventIdFromParam("42"), 42n);
  });

  it("names no event for anything else", () => {
    for (const param of [undefined, "", "abc", "-1", "0", "1.5", "4 2", "9223372036854775808"]) {
      assert.equal(eventIdFromParam(param), undefined, String(param));
    }
  });
});
