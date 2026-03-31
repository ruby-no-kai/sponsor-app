import type {
  ExpenseReport,
  CalculateResponse,
  ExpenseLineItem,
} from "./types";

type RequestOptions = {
  csrfToken: string;
};

async function request<T>(
  url: string,
  method: string,
  opts: RequestOptions,
  body?: Record<string, unknown>,
): Promise<T> {
  const resp = await fetch(url, {
    method,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": opts.csrfToken,
      Accept: "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`API error ${resp.status}: ${text}`);
  }
  return resp.json();
}

export function fetchReport(
  url: string,
  opts: RequestOptions,
): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "GET", opts);
}

export function fetchCalculate(
  url: string,
  opts: RequestOptions,
): Promise<CalculateResponse> {
  return request<CalculateResponse>(url, "GET", opts);
}

export function updateReport(
  url: string,
  opts: RequestOptions,
): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "PATCH", opts);
}

export function createLineItem(
  url: string,
  data: Partial<ExpenseLineItem> & { file_ids?: number[] },
  opts: RequestOptions,
): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "POST", opts, {
    expense_line_item: data,
  });
}

export function updateLineItem(
  url: string,
  id: number,
  data: Partial<ExpenseLineItem> & { file_ids?: number[] },
  opts: RequestOptions,
): Promise<ExpenseReport> {
  return request<ExpenseReport>(`${url}/${id}`, "PATCH", opts, {
    expense_line_item: data,
  });
}

export function deleteLineItem(
  url: string,
  id: number,
  opts: RequestOptions,
): Promise<ExpenseReport> {
  return request<ExpenseReport>(`${url}/${id}`, "DELETE", opts);
}

export function submitReport(
  url: string,
  opts: RequestOptions,
): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "POST", opts);
}

export function withdrawSubmission(
  url: string,
  opts: RequestOptions,
): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "DELETE", opts);
}

export function createReview(
  url: string,
  data: { action_type: string; comment?: string | null },
  opts: RequestOptions,
): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "POST", opts, data);
}

export function deleteFile(
  url: string,
  id: number,
  opts: RequestOptions,
): Promise<void> {
  return request<void>(`${url}/${id}`, "DELETE", opts);
}
