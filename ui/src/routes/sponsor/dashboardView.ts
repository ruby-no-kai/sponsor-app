import { ExpenseReportSummary_Status } from "../../gen/rubykaigi/sponsor_app/expense_report_summary_pb.ts";
import type { ExpenseReportSummary } from "../../gen/rubykaigi/sponsor_app/expense_report_summary_pb.ts";
import { SponsorEventStatus } from "../../gen/rubykaigi/sponsor_app/sponsor_event_status_pb.ts";
import type { SponsorEventSummary } from "../../gen/rubykaigi/sponsor_app/sponsor_event_summary_pb.ts";
import type { Sponsorship } from "../../gen/rubykaigi/sponsor_app/sponsorship_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { TitoDiscountCode_Kind } from "../../gen/rubykaigi/sponsor_app/tito_discount_code_pb.ts";

// Kumo Badge variants the dashboard uses.
export type Tone = "success" | "info" | "warning" | "error" | "neutral";

// A translation key with the badge tone it shows in.
export type Label = { key: string; tone: Tone };

const EVENT_STATUS_LABELS: Readonly<Record<SponsorEventStatus, Label>> = {
  [SponsorEventStatus.UNSPECIFIED]: {
    key: "sponsorships.show.events.status_pending",
    tone: "neutral",
  },
  [SponsorEventStatus.PENDING]: { key: "sponsorships.show.events.status_pending", tone: "warning" },
  [SponsorEventStatus.ACCEPTED]: {
    key: "sponsorships.show.events.status_accepted",
    tone: "success",
  },
  [SponsorEventStatus.REJECTED]: { key: "sponsorships.show.events.status_rejected", tone: "error" },
  [SponsorEventStatus.WITHDRAWN]: {
    key: "sponsorships.show.events.status_withdrawn",
    tone: "neutral",
  },
};

const EXPENSE_REPORT_STATUS_KEY = "activerecord.attributes.expense_report/status";

const EXPENSE_REPORT_STATUS_LABELS: Readonly<Record<ExpenseReportSummary_Status, Label>> = {
  [ExpenseReportSummary_Status.UNSPECIFIED]: {
    key: `${EXPENSE_REPORT_STATUS_KEY}.draft`,
    tone: "neutral",
  },
  [ExpenseReportSummary_Status.DRAFT]: {
    key: `${EXPENSE_REPORT_STATUS_KEY}.draft`,
    tone: "neutral",
  },
  [ExpenseReportSummary_Status.SUBMITTED]: {
    key: `${EXPENSE_REPORT_STATUS_KEY}.submitted`,
    tone: "info",
  },
  [ExpenseReportSummary_Status.APPROVED]: {
    key: `${EXPENSE_REPORT_STATUS_KEY}.approved`,
    tone: "success",
  },
  [ExpenseReportSummary_Status.REJECTED]: {
    key: `${EXPENSE_REPORT_STATUS_KEY}.rejected`,
    tone: "error",
  },
};

const DISCOUNT_CODE_KEYS: Readonly<Record<TitoDiscountCode_Kind, string>> = {
  [TitoDiscountCode_Kind.UNSPECIFIED]: "sponsorships.show.tickets.attendee_url",
  [TitoDiscountCode_Kind.ATTENDEE]: "sponsorships.show.tickets.attendee_url",
  [TitoDiscountCode_Kind.BOOTH_STAFF]: "sponsorships.show.tickets.booth_staff_url",
  [TitoDiscountCode_Kind.BOOTH_PAID]: "sponsorships.show.tickets.booth_paid_url",
};

// A value newer than this build shows as the earliest stage.
export function eventStatusLabel(status: SponsorEventStatus): Label {
  return EVENT_STATUS_LABELS[status] ?? EVENT_STATUS_LABELS[SponsorEventStatus.PENDING];
}

export function expenseReportStatusLabel(status: ExpenseReportSummary_Status): Label {
  return (
    EXPENSE_REPORT_STATUS_LABELS[status] ??
    EXPENSE_REPORT_STATUS_LABELS[ExpenseReportSummary_Status.DRAFT]
  );
}

export function discountCodeKey(kind: TitoDiscountCode_Kind): string {
  return DISCOUNT_CODE_KEYS[kind] ?? DISCOUNT_CODE_KEYS[TitoDiscountCode_Kind.ATTENDEE];
}

// One open action of the sponsorship: a sentence, and the button that goes to it.
export type TodoItem = {
  id: string;
  key: string;
  vars?: Record<string, string>;
  action?: { key: string; href: string };
};

type TodoSource = {
  amendmentOpen: boolean;
  sponsorship: Pick<Sponsorship, "state" | "boothAssigned" | "customized">;
  hasExhibition: boolean;
  expenseReport: Pick<ExpenseReportSummary, "status"> | undefined;
  events: readonly Pick<SponsorEventSummary, "id" | "title" | "status">[];
};

// What the sponsor still has to do, from what the dashboard already knows. Empty when nothing is
// open.
export function todoItems(
  source: TodoSource,
  hrefs: { base: string; expenseReport: string },
): TodoItem[] {
  const items: TodoItem[] = [];
  const { sponsorship } = source;

  if (sponsorship.boothAssigned && !source.hasExhibition) {
    items.push({
      id: "booth",
      key: "sponsor_ui.dashboard.todo.booth_details",
      action: {
        key: "sponsor_ui.dashboard.todo.booth_details_action",
        href: `${hrefs.base}/exhibition/new`,
      },
    });
  }

  const status = source.expenseReport?.status;
  if (sponsorship.customized && status !== undefined) {
    const key =
      status === ExpenseReportSummary_Status.REJECTED
        ? "sponsor_ui.dashboard.todo.expense_rejected"
        : status === ExpenseReportSummary_Status.DRAFT ||
            status === ExpenseReportSummary_Status.UNSPECIFIED
          ? "sponsor_ui.dashboard.todo.expense_draft"
          : undefined;
    if (key !== undefined) {
      items.push({
        id: "expense",
        key,
        action: { key: "sponsor_ui.dashboard.todo.expense_action", href: hrefs.expenseReport },
      });
    }
  }

  for (const event of source.events) {
    if (event.status !== SponsorEventStatus.REJECTED) continue;
    items.push({
      id: `event-${event.id}`,
      key: "sponsor_ui.dashboard.todo.event_changes",
      vars: { title: event.title },
      action: {
        key: "sponsor_ui.dashboard.todo.event_action",
        href: `${hrefs.base}/events/${event.id}`,
      },
    });
  }

  if (sponsorship.state !== SponsorshipState.ACTIVE) {
    items.push({
      id: "confirmation",
      key: "sponsor_ui.dashboard.todo.not_confirmed",
      action: source.amendmentOpen
        ? {
            key: "sponsor_ui.dashboard.todo.not_confirmed_action",
            href: `${hrefs.base}/edit`,
          }
        : undefined,
    });
  }
  return items;
}

// The booth line of the plan card, which names the furthest of assigned, requested and eligible.
export function boothSummaryKey(
  sponsorship: Pick<Sponsorship, "boothAssigned" | "boothRequested" | "boothEligible">,
): string | undefined {
  if (sponsorship.boothAssigned) return "sponsor_ui.dashboard.booth.assigned";
  if (sponsorship.boothRequested) return "sponsor_ui.dashboard.booth.requested";
  if (sponsorship.boothEligible) return "sponsor_ui.dashboard.booth.none";
  return undefined;
}

// Announcements shown in full, and those folded away.
export function splitAnnouncements<T>(announcements: readonly T[], shown = 2): [T[], T[]] {
  return [announcements.slice(0, shown), announcements.slice(shown)];
}
