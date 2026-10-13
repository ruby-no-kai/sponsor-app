import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { TitoDiscountCode_Kind } from "../../gen/rubykaigi/sponsor_app/tito_discount_code_pb.ts";
import {
  badgeText,
  invitationKey,
  newRetractionPath,
  releaseLabel,
  ticketStateLabel,
} from "./passesView.ts";

describe("releaseLabel", () => {
  it("colours the releases the organizers set up as the HAML page does", () => {
    assert.deepEqual(releaseLabel("exhibitor-paid"), {
      key: "pass_redemptions.index.release_type.exhibitor-paid",
      fallback: "exhibitor-paid",
      variant: "warning",
    });
    assert.equal(releaseLabel("sponsor").variant, "success");
    assert.equal(releaseLabel("constructor").variant, "secondary");
  });
});

describe("ticketStateLabel", () => {
  it("shows a voided ticket as void, whatever its state", () => {
    assert.deepEqual(ticketStateLabel({ state: "complete", void: true }), {
      key: "pass_redemptions.index.state.void",
      fallback: "void",
      variant: "error",
    });
  });

  it("shows a state the page does not know as Tito names it", () => {
    assert.equal(ticketStateLabel({ state: "incomplete", void: false }).variant, "warning");
    assert.deepEqual(ticketStateLabel({ state: "reserved", void: false }), {
      key: "pass_redemptions.index.state.reserved",
      fallback: "reserved",
      variant: "info",
    });
  });
});

describe("badgeText", () => {
  it("falls back where the locale files lack the key", () => {
    const translations: Record<string, string> = { "pass_redemptions.index.state.void": "Void" };
    const lookup = (key: string) => translations[key] ?? key;

    assert.equal(badgeText(lookup, ticketStateLabel({ state: "complete", void: true })), "Void");
    assert.equal(badgeText(lookup, releaseLabel("speaker")), "speaker");
  });
});

describe("invitationKey", () => {
  it("names each code as the HAML page does", () => {
    assert.equal(
      invitationKey(TitoDiscountCode_Kind.BOOTH_PAID),
      "pass_redemptions.index.invitation.booth_paid_url",
    );
    assert.equal(
      invitationKey(99 as TitoDiscountCode_Kind),
      "pass_redemptions.index.invitation.attendee_url",
    );
  });
});

describe("newRetractionPath", () => {
  it("points at the form under the pass redemptions", () => {
    assert.equal(
      newRetractionPath("rubykaigi2048", "101"),
      "/conferences/rubykaigi2048/sponsorship/pass_redemptions/101/retraction/new",
    );
  });
});
