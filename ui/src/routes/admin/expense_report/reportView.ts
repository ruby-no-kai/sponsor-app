import { ExpenseReport_Status } from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type {
  ExpenseFile,
  ExpenseReport,
} from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type { Label } from "../sponsorshipView.ts";

export const EXPENSE_REPORT_STATUS_LABELS: Readonly<Record<ExpenseReport_Status, Label>> = {
  [ExpenseReport_Status.UNSPECIFIED]: { text: "unknown", tone: "outline" },
  [ExpenseReport_Status.DRAFT]: { text: "draft", tone: "outline" },
  [ExpenseReport_Status.SUBMITTED]: { text: "submitted", tone: "info" },
  [ExpenseReport_Status.APPROVED]: { text: "approved", tone: "success" },
  [ExpenseReport_Status.REJECTED]: { text: "rejected", tone: "error" },
};

// Staff may change anything but an approved report, which the server refuses to change.
export function isReadOnly(report: Pick<ExpenseReport, "status">): boolean {
  return report.status === ExpenseReport_Status.APPROVED;
}

export function fileName(file: Pick<ExpenseFile, "id" | "filename">): string {
  return file.filename ?? `File #${file.id}`;
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
