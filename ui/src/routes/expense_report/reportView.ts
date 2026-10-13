import type { Timestamp } from "@bufbuild/protobuf/wkt";
import {
  ExpenseReport_Status,
  ExpenseReportReview_Action,
} from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type {
  ExpenseFile,
  ExpenseLineItem,
  ExpenseReport,
} from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type { Label } from "../admin/sponsorshipView.ts";
import { subtractAmounts } from "./amounts.ts";
import type { EditorText } from "./text.ts";

// Who is editing: staff, with every report but an approved one open to them, or the sponsor.
export type Role = "admin" | "sponsor";

export const EXPENSE_REPORT_STATUS_LABELS: Readonly<Record<ExpenseReport_Status, Label>> = {
  [ExpenseReport_Status.UNSPECIFIED]: { text: "unknown", tone: "outline" },
  [ExpenseReport_Status.DRAFT]: { text: "draft", tone: "outline" },
  [ExpenseReport_Status.SUBMITTED]: { text: "submitted", tone: "info" },
  [ExpenseReport_Status.APPROVED]: { text: "approved", tone: "success" },
  [ExpenseReport_Status.REJECTED]: { text: "rejected", tone: "error" },
};

// What the organizers decided, while the report stands as they left it. A report sent back to
// draft or submitted again has no verdict.
export type Verdict =
  | { kind: "approved"; at: Timestamp | undefined }
  | { kind: "rejected"; comment: string };

export function verdictOf(
  report: Pick<ExpenseReport, "status" | "latestReview">,
): Verdict | undefined {
  const review = report.latestReview;
  if (review === undefined) return undefined;
  if (
    report.status === ExpenseReport_Status.APPROVED &&
    review.action === ExpenseReportReview_Action.APPROVE
  ) {
    return { kind: "approved", at: review.createdAt };
  }
  if (
    report.status === ExpenseReport_Status.REJECTED &&
    review.action === ExpenseReportReview_Action.REJECT
  ) {
    return { kind: "rejected", comment: review.comment ?? "" };
  }
  return undefined;
}

// Staff may change anything but an approved report. A sponsor may not change one under review
// either. The server refuses these changes too.
export function isReadOnly(report: Pick<ExpenseReport, "status">, role: Role): boolean {
  return (
    report.status === ExpenseReport_Status.APPROVED ||
    (role === "sponsor" && report.status === ExpenseReport_Status.SUBMITTED)
  );
}

export function fileName(file: Pick<ExpenseFile, "id" | "filename">, text: EditorText): string {
  return file.filename ?? text("file_fallback_name", { id: file.id });
}

// The files no line item attaches.
export function unlinkedFiles(report: Pick<ExpenseReport, "files" | "lineItems">): ExpenseFile[] {
  const linked = new Set(report.lineItems.flatMap((item) => item.fileIds));
  return report.files.filter((file) => !linked.has(file.id));
}

// Which pane the editor opens on, kept in the URL's fragment as #item-ID or #file-ID.
export type Selection = { kind: "item"; id: string } | { kind: "file"; id: string } | undefined;

export function selectionFromHash(hash: string): Selection {
  const match = /^#(item|file)-(\d+)$/.exec(hash);
  if (match === null) return undefined;
  const [, kind, id = ""] = match;
  return { kind: kind === "item" ? "item" : "file", id };
}

export function hashOf(selection: Selection): string {
  return selection === undefined ? "" : `#${selection.kind}-${selection.id}`;
}

// Line items that attach the same files, in the order each set first appears. A line item without
// files is a group of its own.
export type LineItemGroup = { key: string; fileIds: string[]; items: ExpenseLineItem[] };

function compareIds(a: string, b: string): number {
  const [x, y] = [BigInt(a), BigInt(b)];
  return x < y ? -1 : x > y ? 1 : 0;
}

export function groupLineItems(lineItems: readonly ExpenseLineItem[]): LineItemGroup[] {
  const groups = new Map<string, LineItemGroup>();
  for (const item of lineItems) {
    const fileIds = [...item.fileIds].sort(compareIds);
    const key = fileIds.join(",") || "none";
    const group = groups.get(key);
    if (group === undefined) groups.set(key, { key, fileIds, items: [item] });
    else group.items.push(item);
  }
  return [...groups.values()];
}

// What a sponsor is shown before submitting, to catch what the organizers would send back.
export type SubmissionChecks = {
  groups: LineItemGroup[];
  unlinkedFiles: ExpenseFile[];
  // What the fee leaves after the expenses, negative when they exceed it.
  remaining: string | undefined;
  overage: boolean;
  someWithoutFiles: boolean;
};

export function submissionChecks(
  report: Pick<ExpenseReport, "lineItems" | "files" | "totalAmount">,
  totalFee: string,
): SubmissionChecks {
  const remaining = subtractAmounts(totalFee, report.totalAmount);
  return {
    groups: groupLineItems(report.lineItems),
    unlinkedFiles: unlinkedFiles(report),
    remaining,
    overage: remaining?.startsWith("-") ?? false,
    someWithoutFiles: report.lineItems.some((item) => item.fileIds.length === 0),
  };
}
