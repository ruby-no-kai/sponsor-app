import { fromJson, type JsonValue } from "@bufbuild/protobuf";
import type { ExpenseReport, ExpenseLineItem } from "./types";
import {
  ExpenseReportCalculationSchema,
  type ExpenseReportCalculation,
} from "../gen/rubykaigi/sponsor_app/expense_report_pb";
import Rails from "@rails/ujs";

async function request<T>(url: string, method: string, body?: Record<string, unknown>): Promise<T> {
  const headers: Record<string, string> = {
    "X-CSRF-Token": Rails.csrfToken() || "",
    Accept: "application/json",
  };
  if (body) headers["Content-Type"] = "application/json";

  const resp = await fetch(url, {
    method,
    credentials: "include",
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`API error ${resp.status}: ${text}`);
  }
  return resp.json();
}

export function fetchReport(url: string): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "GET");
}

export async function fetchCalculate(url: string): Promise<ExpenseReportCalculation> {
  const json = await request<JsonValue>(url, "GET");
  return fromJson(ExpenseReportCalculationSchema, json, { ignoreUnknownFields: true });
}

export function updateReport(url: string): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "PATCH");
}

export function createLineItem(
  url: string,
  data: Partial<ExpenseLineItem> & { file_ids?: number[] },
): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "POST", {
    expense_line_item: data,
  });
}

export function updateLineItem(
  url: string,
  id: number,
  data: Partial<ExpenseLineItem> & { file_ids?: number[] },
): Promise<ExpenseReport> {
  return request<ExpenseReport>(`${url}/${id}`, "PATCH", {
    expense_line_item: data,
  });
}

export function deleteLineItem(url: string, id: number): Promise<ExpenseReport> {
  return request<ExpenseReport>(`${url}/${id}`, "DELETE");
}

export function submitReport(url: string): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "POST");
}

export function withdrawSubmission(url: string): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "DELETE");
}

export function createReview(
  url: string,
  data: { action_type: string; comment?: string | null },
): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "POST", data);
}

export function deleteFile(url: string, id: number): Promise<void> {
  return request<void>(`${url}/${id}`, "DELETE");
}
