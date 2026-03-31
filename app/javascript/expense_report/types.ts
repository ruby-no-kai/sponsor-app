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

export type EditorProps = {
  role: EditorRole;
  reportUrl: string;
  lineItemsUrl: string;
  submissionUrl?: string;
  reviewsUrl?: string;
  calculateUrl: string;
  filesUrl: string;
  csrfToken: string;
};
