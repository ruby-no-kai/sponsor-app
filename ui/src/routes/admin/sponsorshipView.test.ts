import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import {
  AdminSponsorshipSchema,
  AdminSponsorship_TitoDiscountCode_Kind,
} from "../../gen/rubykaigi/sponsor_app/admin_sponsorship_pb.ts";
import { ExpenseReport_Status } from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { EXPENSE_REPORT_STATUS_LABELS } from "../expense_report/reportView.ts";
import {
  boothStatus,
  customizationStatus,
  isOverWordLimit,
  labelOf,
  titoKindLabel,
  wordCountText,
} from "./sponsorshipView.ts";

const withBooth = { id: 1n, name: "Platinum", boothSize: 2, wordsLimit: 20, wordsLimitHard: 22 };
const withoutBooth = { id: 2n, name: "Silver", boothSize: 0, wordsLimit: 10, wordsLimitHard: 11 };

function sponsorship(fields: Parameters<typeof create<typeof AdminSponsorshipSchema>>[1]) {
  return create(AdminSponsorshipSchema, fields);
}

describe("boothStatus", () => {
  it("flags combinations to look into ahead of the plain states", () => {
    const status = (boothRequested: boolean, boothAssigned: boolean, plan?: typeof withBooth) =>
      boothStatus(sponsorship({ boothRequested, boothAssigned, plan })).text;

    assert.equal(status(false, true, withBooth), "Assigned but not requested");
    assert.equal(status(true, true, withoutBooth), "Not eligible but assigned");
    assert.equal(status(true, false, undefined), "Not eligible but requested");
    assert.equal(status(true, true, withBooth), "Assigned");
    assert.equal(status(true, false, withBooth), "Requested");
    assert.equal(status(false, false, withBooth), "Eligible");
    assert.equal(status(false, false, withoutBooth), "N/A");
  });
});

describe("customizationStatus", () => {
  it("tells a confirmed package from a tentative one", () => {
    assert.equal(customizationStatus(sponsorship({ customization: true })), undefined);
    assert.deepEqual(customizationStatus(sponsorship({ customizationName: "Lounge" })), {
      name: "Lounge",
      confirmed: false,
    });
  });
});

describe("wordCountText and isOverWordLimit", () => {
  it("compare the count with the plan's limits", () => {
    assert.equal(wordCountText(sponsorship({ wordCount: 1 })), "1 word");
    assert.equal(
      wordCountText(sponsorship({ wordCount: 21, plan: withBooth })),
      "21 words (limit 20, refused past 22)",
    );
    assert.equal(isOverWordLimit(sponsorship({ wordCount: 21, plan: withBooth })), true);
    assert.equal(isOverWordLimit(sponsorship({ wordCount: 21 })), false);
  });
});

describe("labels", () => {
  it("name every known value and survive an unknown one", () => {
    assert.equal(
      titoKindLabel(AdminSponsorship_TitoDiscountCode_Kind.BOOTH_PAID),
      "Exhibitor (Paid)",
    );
    assert.equal(
      labelOf(EXPENSE_REPORT_STATUS_LABELS, ExpenseReport_Status.SUBMITTED).text,
      "submitted",
    );
    assert.equal(labelOf(EXPENSE_REPORT_STATUS_LABELS, 99 as never).text, "99");
  });
});
