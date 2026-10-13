import {
  create,
  fromJson,
  toJson,
  type JsonObject,
  type JsonValue,
  type MessageInitShape,
} from "@bufbuild/protobuf";
import type { ExpenseReport } from "./types";
import {
  ExpenseLineItemInputSchema,
  ExpenseReportCalculationSchema,
  type ExpenseLineItemInput,
  type ExpenseReportCalculation,
} from "../gen/rubykaigi/sponsor_app/expense_report_pb";
import { ExpenseLineItemPatchSchema } from "../gen/rubykaigi/sponsor_app/expense_line_item_patch_pb";
import { ExpenseReportReviewInputSchema } from "../gen/rubykaigi/sponsor_app/admin_expense_reports_pb";
import Rails from "@rails/ujs";

async function request<T>(url: string, method: string, body?: JsonValue): Promise<T> {
  const headers: Record<string, string> = {
    "X-CSRF-Token": Rails.csrfToken() || "",
    Accept: "application/json",
  };
  if (body !== undefined) headers["Content-Type"] = "application/json";

  const resp = await fetch(url, {
    method,
    credentials: "include",
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
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

type ExpenseLineItemInputInit = Omit<
  Exclude<MessageInitShape<typeof ExpenseLineItemInputSchema>, ExpenseLineItemInput>,
  "$typeName"
>;

// Fields of a line item to write. null clears a field, and a field left out keeps its value.
export type ExpenseLineItemFields = {
  [K in keyof ExpenseLineItemInputInit]?: ExpenseLineItemInputInit[K] | null;
};

// An ExpenseLineItemPatch whose field_mask names every field `fields` gives, null ones included.
function expenseLineItemPatch(fields: ExpenseLineItemFields): JsonObject {
  // Lists every field, so field_mask cannot name one whose value is left behind.
  const input = {
    title: fields.title ?? undefined,
    notes: fields.notes ?? undefined,
    amount: fields.amount ?? undefined,
    taxRate: fields.taxRate ?? undefined,
    taxAmount: fields.taxAmount ?? undefined,
    preliminal: fields.preliminal ?? undefined,
    position: fields.position ?? undefined,
    fileIds: fields.fileIds ?? undefined,
  } satisfies Record<keyof ExpenseLineItemInputInit, unknown>;
  const given: Record<string, unknown> = fields;
  const masked = ExpenseLineItemInputSchema.fields.filter(
    (field) => given[field.localName] !== undefined,
  );
  const patch = create(ExpenseLineItemPatchSchema, {
    expenseLineItem: input,
    fieldMask: masked.map((field) => field.name),
  });
  const json = toJson(ExpenseLineItemPatchSchema, patch, {
    useProtoFieldName: true,
    alwaysEmitImplicit: true,
  }) as JsonObject;
  // The masked fields alone, cleared ones as null, so a server that ignores field_mask
  // mid-deploy makes the same change.
  const item = json.expense_line_item as JsonObject;
  json.expense_line_item = Object.fromEntries(
    masked.map((field) => [field.name, item[field.name] ?? null]),
  );
  return json;
}

export function createLineItem(url: string, fields: ExpenseLineItemFields): Promise<ExpenseReport> {
  return request<ExpenseReport>(url, "POST", expenseLineItemPatch(fields));
}

export function updateLineItem(
  url: string,
  id: number,
  fields: ExpenseLineItemFields,
): Promise<ExpenseReport> {
  return request<ExpenseReport>(`${url}/${id}`, "PATCH", expenseLineItemPatch(fields));
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
  input: MessageInitShape<typeof ExpenseReportReviewInputSchema>,
): Promise<ExpenseReport> {
  const body = toJson(
    ExpenseReportReviewInputSchema,
    create(ExpenseReportReviewInputSchema, input),
    {
      useProtoFieldName: true,
    },
  );
  return request<ExpenseReport>(url, "POST", body);
}

export function deleteFile(url: string, id: number): Promise<void> {
  return request<void>(`${url}/${id}`, "DELETE");
}
