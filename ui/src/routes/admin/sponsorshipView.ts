import { toJsonString } from "@bufbuild/protobuf";
import { ValueSchema } from "@bufbuild/protobuf/wkt";
import type { Value } from "@bufbuild/protobuf/wkt";
import {
  AdminSponsorship_ExpenseReport_Status,
  AdminSponsorship_TitoDiscountCode_Kind,
} from "../../gen/rubykaigi/sponsor_app/admin_sponsorship_pb.ts";
import type { AdminSponsorship } from "../../gen/rubykaigi/sponsor_app/admin_sponsorship_pb.ts";
import { EditingHistoryEntry_Change_Operation } from "../../gen/rubykaigi/sponsor_app/editing_history_pb.ts";

// Whether a sponsor-supplied URL is safe to link to: http or https, never javascript: and the like.
export function isWebUrl(url: string): boolean {
  try {
    return ["http:", "https:"].includes(new URL(url).protocol);
  } catch {
    return false;
  }
}

// Kumo Badge variants this page uses.
export type Tone = "success" | "info" | "warning" | "error" | "outline";

export type Label = { text: string; tone: Tone };

// Where the booth stands, flagging the combinations organizers should look into.
export function boothStatus(
  sponsorship: Pick<AdminSponsorship, "boothRequested" | "boothAssigned" | "plan">,
): Label {
  const { boothRequested, boothAssigned } = sponsorship;
  const eligible = (sponsorship.plan?.boothSize ?? 0) > 0;
  if (boothAssigned && !boothRequested)
    return { text: "Assigned but not requested", tone: "error" };
  if (!eligible && boothAssigned) return { text: "Not eligible but assigned", tone: "error" };
  if (!eligible && boothRequested) return { text: "Not eligible but requested", tone: "warning" };
  if (boothAssigned) return { text: "Assigned", tone: "success" };
  if (boothRequested) return { text: "Requested", tone: "info" };
  if (eligible) return { text: "Eligible", tone: "outline" };
  return { text: "N/A", tone: "outline" };
}

// The custom package as the sponsor list shows it: confirmed, or named but tentative.
export function customizationStatus(
  sponsorship: Pick<AdminSponsorship, "customization" | "customizationName">,
): { name: string; confirmed: boolean } | undefined {
  const { customization, customizationName } = sponsorship;
  if (customizationName === undefined) return undefined;
  return { name: customizationName, confirmed: customization };
}

// The word count against the plan's limits, such as "12 words (limit 20, refused past 22)".
export function wordCountText(sponsorship: Pick<AdminSponsorship, "wordCount" | "plan">): string {
  const { wordCount, plan } = sponsorship;
  const count = `${wordCount} ${wordCount === 1 ? "word" : "words"}`;
  return plan === undefined
    ? count
    : `${count} (limit ${plan.wordsLimit}, refused past ${plan.wordsLimitHard})`;
}

export function isOverWordLimit(
  sponsorship: Pick<AdminSponsorship, "wordCount" | "plan">,
): boolean {
  const { wordCount, plan } = sponsorship;
  return plan !== undefined && wordCount > plan.wordsLimit;
}

// The ticket kinds as the HAML page names them.
export function titoKindLabel(kind: AdminSponsorship_TitoDiscountCode_Kind): string {
  switch (kind) {
    case AdminSponsorship_TitoDiscountCode_Kind.ATTENDEE:
      return "Attendee";
    case AdminSponsorship_TitoDiscountCode_Kind.BOOTH_STAFF:
      return "Exhibitor";
    case AdminSponsorship_TitoDiscountCode_Kind.BOOTH_PAID:
      return "Exhibitor (Paid)";
    default:
      return `Kind ${kind}`;
  }
}

export const EXPENSE_REPORT_STATUS_LABELS: Readonly<
  Record<AdminSponsorship_ExpenseReport_Status, Label>
> = {
  [AdminSponsorship_ExpenseReport_Status.UNSPECIFIED]: { text: "unknown", tone: "outline" },
  [AdminSponsorship_ExpenseReport_Status.DRAFT]: { text: "draft", tone: "outline" },
  [AdminSponsorship_ExpenseReport_Status.SUBMITTED]: { text: "submitted", tone: "info" },
  [AdminSponsorship_ExpenseReport_Status.APPROVED]: { text: "approved", tone: "success" },
  [AdminSponsorship_ExpenseReport_Status.REJECTED]: { text: "rejected", tone: "error" },
};

export const OPERATION_LABELS: Readonly<Record<EditingHistoryEntry_Change_Operation, Label>> = {
  [EditingHistoryEntry_Change_Operation.UNSPECIFIED]: { text: "?", tone: "outline" },
  [EditingHistoryEntry_Change_Operation.ADDED]: { text: "+", tone: "info" },
  [EditingHistoryEntry_Change_Operation.REMOVED]: { text: "-", tone: "error" },
  [EditingHistoryEntry_Change_Operation.CHANGED]: { text: "~", tone: "warning" },
};

// Looks a label up for an enum value the generated code may not know yet.
export function labelOf<K extends number>(labels: Readonly<Record<K, Label>>, value: K): Label {
  return labels[value] ?? { text: String(value), tone: "outline" };
}

// A decimal string such as "120000.0" with thousands separators, as the HAML page shows totals.
export function formatAmount(amount: string): string {
  const [integer = "", fraction] = amount.split(".");
  const grouped = integer.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return fraction === undefined || /^0*$/.test(fraction) ? grouped : `${grouped}.${fraction}`;
}

// A history value as JSON, or a dash when the change has none on that side.
export function formatHistoryValue(value: Value | undefined): string {
  return value === undefined ? "—" : toJsonString(ValueSchema, value);
}
