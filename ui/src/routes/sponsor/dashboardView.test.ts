import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ExpenseReportSummary_Status } from "../../gen/rubykaigi/sponsor_app/expense_report_summary_pb.ts";
import { SponsorEventStatus } from "../../gen/rubykaigi/sponsor_app/sponsor_event_status_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { TitoDiscountCode_Kind } from "../../gen/rubykaigi/sponsor_app/tito_discount_code_pb.ts";
import {
  boothSummaryKey,
  discountCodeKey,
  eventStatusLabel,
  expenseReportStatusLabel,
  splitAnnouncements,
  todoItems,
} from "./dashboardView.ts";

describe("eventStatusLabel", () => {
  it("names each status as the HAML dashboard does", () => {
    assert.deepEqual(eventStatusLabel(SponsorEventStatus.ACCEPTED), {
      key: "sponsorships.show.events.status_accepted",
      tone: "success",
    });
    assert.equal(
      eventStatusLabel(SponsorEventStatus.WITHDRAWN).key,
      "sponsorships.show.events.status_withdrawn",
    );
    assert.equal(
      eventStatusLabel(99 as SponsorEventStatus).key,
      "sponsorships.show.events.status_pending",
    );
  });
});

describe("expenseReportStatusLabel", () => {
  it("names each status with the model's attribute translation", () => {
    assert.deepEqual(expenseReportStatusLabel(ExpenseReportSummary_Status.REJECTED), {
      key: "activerecord.attributes.expense_report/status.rejected",
      tone: "error",
    });
    assert.equal(
      expenseReportStatusLabel(99 as ExpenseReportSummary_Status).key,
      "activerecord.attributes.expense_report/status.draft",
    );
  });
});

describe("discountCodeKey", () => {
  it("labels each kind of ticket", () => {
    assert.equal(
      discountCodeKey(TitoDiscountCode_Kind.BOOTH_STAFF),
      "sponsorships.show.tickets.booth_staff_url",
    );
    assert.equal(
      discountCodeKey(TitoDiscountCode_Kind.BOOTH_PAID),
      "sponsorships.show.tickets.booth_paid_url",
    );
  });
});

describe("boothSummaryKey", () => {
  const booth = { boothAssigned: false, boothRequested: false, boothEligible: false };

  it("names the furthest booth stage reached", () => {
    assert.equal(
      boothSummaryKey({ boothAssigned: true, boothRequested: true, boothEligible: true }),
      "sponsor_ui.dashboard.booth.assigned",
    );
    assert.equal(
      boothSummaryKey({ ...booth, boothRequested: true, boothEligible: true }),
      "sponsor_ui.dashboard.booth.requested",
    );
    assert.equal(
      boothSummaryKey({ ...booth, boothEligible: true }),
      "sponsor_ui.dashboard.booth.none",
    );
    assert.equal(boothSummaryKey(booth), undefined);
  });
});

describe("todoItems", () => {
  const hrefs = { base: "/conferences/c/sponsorship", expenseReport: "/c/expense" };
  const source = {
    amendmentOpen: false,
    sponsorship: { state: SponsorshipState.ACTIVE, boothAssigned: false, customized: false },
    hasExhibition: false,
    expenseReport: undefined,
    events: [],
  };
  const ids = (items: { id: string }[]) => items.map(({ id }) => id);

  it("is empty when nothing is open", () => {
    assert.deepEqual(todoItems(source, hrefs), []);
  });

  it("asks for booth details once a booth is assigned and none were sent", () => {
    const booth = { ...source.sponsorship, boothAssigned: true };
    assert.deepEqual(ids(todoItems({ ...source, sponsorship: booth }, hrefs)), ["booth"]);
    assert.deepEqual(todoItems({ ...source, sponsorship: booth, hasExhibition: true }, hrefs), []);
  });

  it("lists an expense report that is a draft or was returned, not one under review", () => {
    const customized = { ...source.sponsorship, customized: true };
    const report = (status: ExpenseReportSummary_Status) =>
      todoItems({ ...source, sponsorship: customized, expenseReport: { status } }, hrefs);
    assert.equal(
      report(ExpenseReportSummary_Status.DRAFT)[0]?.key,
      "sponsor_ui.dashboard.todo.expense_draft",
    );
    assert.equal(
      report(ExpenseReportSummary_Status.REJECTED)[0]?.key,
      "sponsor_ui.dashboard.todo.expense_rejected",
    );
    assert.deepEqual(report(ExpenseReportSummary_Status.SUBMITTED), []);
    assert.deepEqual(report(ExpenseReportSummary_Status.APPROVED), []);
  });

  it("lists each rejected event with its title", () => {
    const events = [
      { id: 1n, title: "Party", status: SponsorEventStatus.REJECTED },
      { id: 2n, title: "Talk", status: SponsorEventStatus.ACCEPTED },
    ];
    const [item, ...rest] = todoItems({ ...source, events }, hrefs);
    assert.equal(rest.length, 0);
    assert.deepEqual(item?.vars, { title: "Party" });
    assert.equal(item?.action?.href, "/conferences/c/sponsorship/events/1");
  });

  it("offers the application's editor while an unconfirmed application can be amended", () => {
    const pending = { ...source.sponsorship, state: SponsorshipState.PENDING };
    const [closed] = todoItems({ ...source, sponsorship: pending }, hrefs);
    assert.equal(closed?.id, "confirmation");
    assert.equal(closed?.action, undefined);
    const [open] = todoItems({ ...source, sponsorship: pending, amendmentOpen: true }, hrefs);
    assert.equal(open?.action?.href, "/conferences/c/sponsorship/edit");
  });
});

describe("splitAnnouncements", () => {
  it("keeps the newest two in view", () => {
    assert.deepEqual(splitAnnouncements([1, 2, 3, 4]), [
      [1, 2],
      [3, 4],
    ]);
    assert.deepEqual(splitAnnouncements([1]), [[1], []]);
  });
});
