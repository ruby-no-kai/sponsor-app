import { translator } from "../../lib/translator.ts";
import { editorText, STATUS_SCOPE, textKey } from "./text.ts";
import type { EditorText, EditorTextKey, PlainKey, PluralKey } from "./text.ts";

type AdminTexts = Readonly<Record<PlainKey | `${PluralKey}.one` | `${PluralKey}.other`, string>>;

// The staff area is English only, so the editor reads this table where the sponsor area reads the
// locale files.
const ADMIN_TEXTS: AdminTexts = {
  confirm_discard: "You have unsaved changes. Discard them?",
  submit: "Submit for review",
  submitting: "Submitting...",
  withdrawing: "Withdrawing...",
  confirm_withdraw: "Withdraw this submission? You can re-submit later.",
  review_feedback: "Review feedback",
  back: "Back",
  line_items: "Line items",
  no_line_items: "No line items yet",
  files: "Other files",
  drop_to_add: "Drop files to add or %{link}",
  upload: "upload",
  drop_unlinked: "Add as a new file",
  select_line_item: "Select a line item",
  create_from_file: "Create line item from this file",
  delete_file: "Delete this file",
  confirm_delete_file: "Delete this file?",
  preview_file: "Preview file",
  title_label: "Title",
  notes_label: "Notes",
  notes_placeholder: "(optional)",
  tax_mode_label: "Tax mode",
  tax_mode_exclude: "Entered amount excludes tax",
  tax_mode_include: "Entered amount includes tax",
  tax_mode_exempt: "Tax does not apply",
  tax_mode_manual: "Enter amounts manually",
  tax_rate_label: "Tax rate",
  amount_label: "Amount",
  amount_excl: "Amount (excl. tax)",
  amount_incl: "Amount (incl. tax)",
  tax_amount_label: "Tax amount",
  total_incl_label: "Total (incl. tax)",
  attached_files: "Attached files",
  no_files_attached: "No files attached",
  drop_or_upload: "Drop files here or %{link} to attach",
  link_existing: "Link an existing file…",
  save: "Save",
  delete: "Delete",
  confirm_delete_item: "Delete this line item?",
  drop_link_to: 'Link to "%{title}"',
  drop_create_item: "Create new line item",
  select_file: "Select a file to preview",
  no_preview: "Preview not available.",
  download: "Download",
  no_file_badge: "no file",
  no_file_alert:
    "Some line items have no files attached. Attaching files is not mandatory, but please attach receipts or invoices where available.",
  link_to_existing_items: "Link to existing line items",
  link_selected: "Link selected",
  uploading: "Uploading files",
  upload_failed: "Upload failed",
  retry: "Retry",
  discard: "Discard",
  error_unsupported_file: "Unsupported file type: %{names}",
  review_dialog_title: "Review before submission",
  review_dialog_no_files: "No files",
  review_dialog_unlinked_files: "Unlinked files",
  review_dialog_base_fee: "Base sponsorship fee",
  review_dialog_total_expense: "Total expense (excl. tax)",
  review_dialog_remaining: "Remaining (amount to be billed)",
  review_dialog_overage_warning: "The amount exceeding the base fee is not reimbursed.",
  review_dialog_cancel: "Cancel",
  file_fallback_name: "File #%{id}",
  new_item_title: "New expense",
  rate_not_offered: "%{rate} (not offered)",
  saved: "Saved %{title}",
  detach: "Detach %{name}",
  not_saved: "Not saved",
  show: "Show",
  "fields_need_attention.one": "%{field}: %{message}",
  "fields_need_attention.other":
    "%{count} fields need attention, starting with %{field}: %{message}",
  request_id: "Request ID: %{request_id}",
  upload_progress: "Progress",
  upload_status_waiting: "waiting",
  upload_status_uploading: "uploading",
  upload_status_done: "done",
  upload_status_failed: "failed",
  upload_status_discarded: "discarded",
  supported_file_types: "Upload JPEG, PNG, GIF or WebP images, or PDFs.",
  figure_fee: "Fee",
  figure_expense: "Expense",
  figure_tax: "Tax",
  figure_remaining: "Remaining",
  add_item: "Add item",
  duplicate_keep_files: "Duplicate line, keep files",
  preliminal_label: "Preliminary (planned budget, not finalized)",
  preliminal_badge: "preliminary",
  withdraw: "Withdraw submission",
  verdict_approved: "Approved %{date}",
  verdict_rejected: "Rejected: %{comment}",
  change_verdict: "Change the verdict",
  comment_label: "Comment (required to reject)",
  comment_required: "Write a comment for the sponsor to reject this report.",
  approve: "Approve",
  reject: "Reject",
  confirm_approve: "Approve this expense report?",
  confirm_reject: "Reject this expense report?",
  approve_consequence: "Its line items and files can no longer be changed.",
  reject_consequence: "The report goes back to the sponsor with the comment.",
  rejected_next_step: "Edit an item to send this report again",
  approved_locked: "This report is approved and can no longer be edited.",
};

const ADMIN_STATUS_TEXTS = {
  draft: "draft",
  submitted: "submitted",
  approved: "approved",
  rejected: "rejected",
} as const;

// A text's key in the locale files, with the `.one` or `.other` of a plural form kept.
function scopedKey(key: string): string {
  const [, name = key, form = ""] = /^(.*?)(\.(?:one|other))?$/.exec(key) ?? [];
  return `${textKey(name as EditorTextKey)}${form}`;
}

export const ADMIN_TRANSLATIONS: Readonly<Record<string, string>> = {
  ...Object.fromEntries(Object.entries(ADMIN_TEXTS).map(([key, text]) => [scopedKey(key), text])),
  ...Object.fromEntries(
    Object.entries(ADMIN_STATUS_TEXTS).map(([key, text]) => [`${STATUS_SCOPE}.${key}`, text]),
  ),
};

export const ADMIN_EDITOR_TEXT: EditorText = editorText(
  translator({ locale: "en", translations: ADMIN_TRANSLATIONS, orgName: "" }),
);
