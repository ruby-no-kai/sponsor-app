import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { goTo } from "./navigation.ts";
import type { Navigator } from "./navigation.ts";

const BASE = "http://sponsor-app.localhost:1355/conferences";

function recorder() {
  const calls: string[] = [];
  const navigator: Navigator = {
    navigate: (to, { replace }) => calls.push(`navigate ${to}${replace ? " (replace)" : ""}`),
    assign: (url) => calls.push(`assign ${url}`),
    replace: (url) => calls.push(`replace ${url}`),
  };
  return { calls, navigator };
}

describe("goTo", () => {
  it("navigates in place to an SPA path, keeping the query and fragment", () => {
    const { calls, navigator } = recorder();
    goTo("/admin/conferences/rubykaigi2048?hl=ja#sponsorships", {}, navigator, BASE);
    goTo("http://sponsor-app.localhost:1355/admin/conferences", { replace: true }, navigator, BASE);

    assert.deepEqual(calls, [
      "navigate /admin/conferences/rubykaigi2048?hl=ja#sponsorships",
      "navigate /admin/conferences (replace)",
    ]);
  });

  it("loads any other path as a page of its own, so HAML renders it", () => {
    const { calls, navigator } = recorder();
    goTo(
      "/conferences/rubykaigi2048/sponsorship/new?invite_code=abc",
      { replace: true },
      navigator,
      BASE,
    );
    goTo("/session/new", {}, navigator, BASE);

    assert.deepEqual(calls, [
      "replace /conferences/rubykaigi2048/sponsorship/new?invite_code=abc",
      "assign /session/new",
    ]);
  });
});
