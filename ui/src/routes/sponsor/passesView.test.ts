import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { PassRetraction_State } from "../../gen/rubykaigi/sponsor_app/sponsor_passes_pb.ts";
import { TitoDiscountCode_Kind } from "../../gen/rubykaigi/sponsor_app/tito_discount_code_pb.ts";
import type { Vars } from "../../lib/translations.ts";
import {
  REASON_MAX_LENGTH,
  badgeText,
  confirmationError,
  invitationKey,
  isRegistrationId,
  newRetractionPath,
  reasonError,
  releaseLabel,
  retractionErrors,
  retractionRefreshInterval,
  retractionValuesFrom,
  ticketStateLabel,
} from "./passesView.ts";
import type { RetractionValues } from "./passesView.ts";

// Echoes the key and its variables, so a test sees which text was asked for.
const t = (key: string, vars?: Vars) =>
  vars === undefined ? key : `${key} ${JSON.stringify(vars)}`;

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

describe("isRegistrationId", () => {
  it("accepts the digits GetPassRetraction takes", () => {
    assert.ok(isRegistrationId("101"));
    assert.ok(!isRegistrationId("reg-101"));
    assert.ok(!isRegistrationId(""));
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

describe("retractionRefreshInterval", () => {
  it("polls only while the voiding is pending", () => {
    assert.ok(retractionRefreshInterval(PassRetraction_State.PENDING) > 0);
    assert.equal(retractionRefreshInterval(PassRetraction_State.COMPLETED), 0);
    assert.equal(retractionRefreshInterval(undefined), 0);
  });
});

describe("reasonError", () => {
  it("reads the reason's limit from the proto", () => {
    assert.equal(REASON_MAX_LENGTH, 1000);
  });

  it("asks for a reason that is more than spaces", () => {
    assert.equal(reasonError("Mistyped address", t), undefined);
    assert.equal(reasonError(" \n ", t), "sponsor_ui.passes.reason_required");
  });

  it("counts the reason in characters", () => {
    const emoji = "🎫".repeat(REASON_MAX_LENGTH);
    assert.equal(reasonError(emoji, t), undefined);
    assert.equal(
      reasonError(`${emoji}!`, t),
      `sponsor_ui.passes.reason_too_long {"count":${REASON_MAX_LENGTH}}`,
    );
  });
});

describe("confirmationError", () => {
  it("asks for the confirmation", () => {
    assert.equal(confirmationError(true, t), undefined);
    assert.equal(confirmationError(false, t), "sponsor_ui.passes.confirmation_required");
  });
});

describe("retractionValuesFrom", () => {
  it("starts from the stored reason, unconfirmed", () => {
    assert.deepEqual(retractionValuesFrom({ reason: "Mistyped address" }), {
      reason: "Mistyped address",
      confirmed: false,
    });
    assert.deepEqual(retractionValuesFrom({}), { reason: "", confirmed: false });
  });
});

describe("retractionErrors", () => {
  it("passes a reason that is confirmed", () => {
    assert.equal(retractionErrors({ reason: "Mistyped address", confirmed: true }, t), undefined);
  });

  it("names each field that fails its check", () => {
    assert.deepEqual(retractionErrors({ reason: " ", confirmed: false }, t), {
      fields: {
        reason: "sponsor_ui.passes.reason_required",
        confirmed: "sponsor_ui.passes.confirmation_required",
      },
    });
    assert.deepEqual(retractionErrors({ reason: "Mistyped address", confirmed: false }, t), {
      fields: { confirmed: "sponsor_ui.passes.confirmation_required" },
    });
  });
});
