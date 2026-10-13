import { timestampDate } from "@bufbuild/protobuf/wkt";
import type { Timestamp } from "@bufbuild/protobuf/wkt";
import type { ReactNode } from "react";
import { ExpenseReport_Status } from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type { Translate } from "../../lib/translator.ts";
import type { Vars } from "../../lib/translations.ts";

// Where the Rails locale files keep the editor's texts, which the sponsor area reads through
// GetTranslations.
export const EDITOR_SCOPE = "expense_reports.show.editor";

export const STATUS_SCOPE = "activerecord.attributes.expense_report/status";

// Texts with a single form, under EDITOR_SCOPE.
export const PLAIN_KEYS = [
  "confirm_discard",
  "submit",
  "submitting",
  "withdrawing",
  "confirm_withdraw",
  "review_feedback",
  "back",
  "line_items",
  "no_line_items",
  "files",
  "drop_to_add",
  "upload",
  "drop_unlinked",
  "select_line_item",
  "create_from_file",
  "delete_file",
  "confirm_delete_file",
  "preview_file",
  "title_label",
  "notes_label",
  "notes_placeholder",
  "tax_mode_label",
  "tax_mode_exclude",
  "tax_mode_include",
  "tax_mode_exempt",
  "tax_mode_manual",
  "tax_rate_label",
  "amount_label",
  "amount_excl",
  "amount_incl",
  "tax_amount_label",
  "total_incl_label",
  "attached_files",
  "no_files_attached",
  "drop_or_upload",
  "link_existing",
  "save",
  "delete",
  "confirm_delete_item",
  "drop_link_to",
  "drop_create_item",
  "select_file",
  "no_preview",
  "download",
  "no_file_badge",
  "no_file_alert",
  "link_to_existing_items",
  "link_selected",
  "uploading",
  "upload_failed",
  "retry",
  "discard",
  "error_unsupported_file",
  "review_dialog_title",
  "review_dialog_no_files",
  "review_dialog_unlinked_files",
  "review_dialog_base_fee",
  "review_dialog_total_expense",
  "review_dialog_remaining",
  "review_dialog_overage_warning",
  "review_dialog_cancel",
  "file_fallback_name",
  "new_item_title",
  "rate_not_offered",
  "saved",
  "detach",
  "not_saved",
  "show",
  "request_id",
  "upload_progress",
  "upload_status_waiting",
  "upload_status_uploading",
  "upload_status_done",
  "upload_status_failed",
  "upload_status_discarded",
  "supported_file_types",
] as const;

// Texts only the SPA shows, under SPA_SCOPE. The locale files keep them apart from the HAML
// pages' texts, which differ in wording from these.
export const SPA_KEYS = [
  "figure_fee",
  "figure_expense",
  "figure_tax",
  "figure_remaining",
  "add_item",
  "duplicate_keep_files",
  "preliminal_label",
  "preliminal_badge",
  "withdraw",
  "verdict_approved",
  "verdict_rejected",
  "change_verdict",
  "comment_label",
  "comment_required",
  "approve",
  "reject",
  "confirm_approve",
  "confirm_reject",
  "approve_consequence",
  "reject_consequence",
  "rejected_next_step",
  "approved_locked",
] as const;

// Texts with a form per count, stored as `.one` and `.other`.
export const PLURAL_KEYS = ["fields_need_attention"] as const;

export const SPA_SCOPE = "sponsor_ui.expense_reports";

export type PlainKey = (typeof PLAIN_KEYS)[number] | (typeof SPA_KEYS)[number];

export type PluralKey = (typeof PLURAL_KEYS)[number];

export type EditorTextKey = PlainKey | PluralKey;

// What the editor reads its texts through. The sponsor area fills it from the locale files, and
// the staff area from an English table.
export type EditorText = {
  (key: EditorTextKey, vars?: Vars): string;
  rich(key: EditorTextKey, vars: Readonly<Record<string, ReactNode>>): ReactNode;
  status(status: ExpenseReport_Status): string;
  // A day such as "Oct 14", in the language the texts are in.
  day(timestamp: Timestamp): string;
};

const STATUS_NAMES: Readonly<Record<ExpenseReport_Status, string>> = {
  [ExpenseReport_Status.UNSPECIFIED]: "draft",
  [ExpenseReport_Status.DRAFT]: "draft",
  [ExpenseReport_Status.SUBMITTED]: "submitted",
  [ExpenseReport_Status.APPROVED]: "approved",
  [ExpenseReport_Status.REJECTED]: "rejected",
};

// The key of a status's name in the locale files.
export function statusKey(status: ExpenseReport_Status): string {
  return `${STATUS_SCOPE}.${STATUS_NAMES[status]}`;
}

const SPA_KEY_SET: ReadonlySet<string> = new Set(SPA_KEYS);

// The key of a text in the locale files.
export function textKey(key: EditorTextKey): string {
  return `${SPA_KEY_SET.has(key) ? SPA_SCOPE : EDITOR_SCOPE}.${key}`;
}

// A day without its year or time, which the report's own dates are never far from.
export function formatDay(date: Date, locale: string, timeZone?: string): string {
  return new Intl.DateTimeFormat(locale, { month: "short", day: "numeric", timeZone }).format(date);
}

export function editorText(t: Translate): EditorText {
  const text = (key: EditorTextKey, vars?: Vars) => t(textKey(key), vars);
  text.rich = (key: EditorTextKey, vars: Readonly<Record<string, ReactNode>>) =>
    t.rich(textKey(key), vars);
  text.status = (status: ExpenseReport_Status) => t(statusKey(status));
  text.day = (timestamp: Timestamp) => formatDay(timestampDate(timestamp), t.locale);
  return text;
}
