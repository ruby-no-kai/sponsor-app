export type ExpenseReport = {
  id: number;
  status: "draft" | "submitted" | "approved" | "rejected";
  total_amount: string;
  total_tax_amount: string;
  revision: number;
  line_items: ExpenseLineItem[];
  files: ExpenseFile[];
  latest_review: ExpenseReportReview | null;
  created_at: string;
  updated_at: string;
};

export type ExpenseLineItem = {
  id: number;
  title: string;
  notes: string | null;
  amount: string;
  tax_rate: string | null;
  tax_amount: string;
  preliminal: boolean;
  position: number;
  file_ids: number[];
};

export type ExpenseFile = {
  id: number;
  filename: string;
  content_type: string;
  status: "pending" | "uploaded";
  created_at: string;
};

export type ExpenseReportReview = {
  action: "approve" | "reject";
  comment: string | null;
  created_at: string;
};

export type CalculateResponse = {
  tax_rates: string[];
  decimal: number;
  plan_price: string;
  plan_price_booth: string;
  booth_assigned: boolean;
  total_fee: string;
};

export type TaxMode = "exclude" | "include" | "exempt" | "manual";

export type EditorRole = "sponsor" | "admin";

export type EditorI18n = {
  loading: string;
  confirm_discard: string;
  error_load: string;
  fee: string;
  expense: string;
  plus_tax: string;
  remaining: string;
  submit: string;
  submitting: string;
  error_submit: string;
  withdraw: string;
  withdrawing: string;
  confirm_withdraw: string;
  error_withdraw: string;
  review_feedback: string;
  back: string;
  line_items: string;
  add_line_item: string;
  no_line_items: string;
  files: string;
  drop_to_add: string;
  upload: string;
  drop_unlinked: string;
  select_line_item: string;
  create_from_file: string;
  creating: string;
  delete_file: string;
  confirm_delete_file: string;
  preview_file: string;
  title_label: string;
  notes_label: string;
  notes_placeholder: string;
  tax_mode_label: string;
  tax_mode_exclude: string;
  tax_mode_include: string;
  tax_mode_exempt: string;
  tax_mode_manual: string;
  tax_rate_label: string;
  amount_excl: string;
  amount_incl: string;
  tax_amount_label: string;
  preliminal_label: string;
  attached_files: string;
  no_files_attached: string;
  drop_or_upload: string;
  or_separator: string;
  link_existing: string;
  save: string;
  saving: string;
  error_save: string;
  add_same_files: string;
  adding: string;
  error_add: string;
  delete: string;
  deleting: string;
  confirm_delete_item: string;
  error_delete: string;
  error_create: string;
  drop_link_to: string;
  drop_create_item: string;
  select_file: string;
  no_preview: string;
  download: string;
  preliminal_badge: string;
  no_file_badge: string;
  no_file_alert: string;
  link_to_existing_items: string;
  link_selected: string;
  uploading: string;
  upload_failed: string;
  retry: string;
  discard: string;
  error_unsupported_file: string;
  review_dialog_title: string;
  review_dialog_no_files: string;
  review_dialog_unlinked_files: string;
  review_dialog_base_fee: string;
  review_dialog_total_expense: string;
  review_dialog_remaining: string;
  review_dialog_overage_warning: string;
  review_dialog_cancel: string;
};

export type EditorProps = {
  role: EditorRole;
  reportUrl: string;
  lineItemsUrl: string;
  submissionUrl?: string;
  reviewsUrl?: string;
  calculateUrl: string;
  filesUrl: string;
  i18n: EditorI18n;
  statusLabels: Record<string, string>;
};
