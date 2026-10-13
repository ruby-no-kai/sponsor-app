import { ExpenseReport_Status } from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type { Label } from "../sponsorshipView.ts";

export const EXPENSE_REPORT_STATUS_LABELS: Readonly<Record<ExpenseReport_Status, Label>> = {
  [ExpenseReport_Status.UNSPECIFIED]: { text: "unknown", tone: "outline" },
  [ExpenseReport_Status.DRAFT]: { text: "draft", tone: "outline" },
  [ExpenseReport_Status.SUBMITTED]: { text: "submitted", tone: "info" },
  [ExpenseReport_Status.APPROVED]: { text: "approved", tone: "success" },
  [ExpenseReport_Status.REJECTED]: { text: "rejected", tone: "error" },
};
