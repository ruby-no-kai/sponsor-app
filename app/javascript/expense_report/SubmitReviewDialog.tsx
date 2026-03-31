import React, { useRef, useEffect } from "react";
import type { ExpenseReport, ExpenseLineItem, CalculateResponse } from "./types";
import { useI18n } from "./I18nContext";
import { formatAmount } from "./format";

type SubmitReviewDialogProps = {
  open: boolean;
  report: ExpenseReport;
  calcData: CalculateResponse;
  onConfirm: () => void;
  onCancel: () => void;
  submitting: boolean;
};

type LineItemGroup = {
  key: string;
  fileNames: string[];
  items: ExpenseLineItem[];
};

function groupLineItems(report: ExpenseReport): {
  groups: LineItemGroup[];
  unlinkedFiles: { id: number; filename: string }[];
} {
  const fileMap = new Map(report.files.map((f) => [f.id, f]));
  const grouped = new Map<string, { fileIds: number[]; items: ExpenseLineItem[] }>();

  for (const item of report.line_items) {
    const key = [...item.file_ids].sort((a, b) => a - b).join(",") || "_none";
    const existing = grouped.get(key);
    if (existing) {
      existing.items.push(item);
    } else {
      grouped.set(key, { fileIds: [...item.file_ids].sort((a, b) => a - b), items: [item] });
    }
  }

  const groups: LineItemGroup[] = [];
  for (const [key, { fileIds, items }] of grouped) {
    const fileNames = fileIds.map((id) => fileMap.get(id)?.filename || `File #${id}`);
    groups.push({ key, fileNames, items });
  }

  const linkedFileIds = new Set(report.line_items.flatMap((i) => i.file_ids));
  const unlinkedFiles = report.files.filter((f) => !linkedFileIds.has(f.id));

  return { groups, unlinkedFiles };
}

export function SubmitReviewDialog({
  open,
  report,
  calcData,
  onConfirm,
  onCancel,
  submitting,
}: SubmitReviewDialogProps) {
  const i18n = useI18n();
  const dialogRef = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (open && !dialog.open) {
      dialog.showModal();
      dialog.scrollTop = 0;
    } else if (!open && dialog.open) {
      dialog.close();
    }
  }, [open]);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    const handleCancel = (e: Event) => {
      if (submitting) {
        e.preventDefault();
      } else {
        e.preventDefault();
        onCancel();
      }
    };
    dialog.addEventListener("cancel", handleCancel);
    return () => dialog.removeEventListener("cancel", handleCancel);
  }, [submitting, onCancel]);

  if (!open) {
    return <dialog ref={dialogRef} />;
  }

  const { groups, unlinkedFiles } = groupLineItems(report);
  const d = calcData.decimal;
  const fee = parseFloat(calcData.total_fee) || 0;
  const expense = parseFloat(report.total_amount) || 0;
  const remaining = fee - expense;

  return (
    <dialog
      ref={dialogRef}
      style={{
        border: "1px solid #dee2e6",
        borderRadius: "8px",
        padding: "1.5rem",
        minWidth: "min(500px, 90vw)",
        maxWidth: "min(700px, 90vw)",
        maxHeight: "80vh",
        overflow: "auto",
      }}
    >
      <h5 className="mb-3">{i18n.review_dialog_title}</h5>

      {groups.map((group) => (
        <div key={group.key} className="mb-3">
          <div className="small font-weight-bold text-muted mb-1">
            {group.fileNames.length > 0 ? group.fileNames.join(", ") : i18n.review_dialog_no_files}
          </div>
          {group.items.map((item) => (
            <div
              key={item.id}
              className="d-flex justify-content-between align-items-center py-1 pl-2 border-left"
              style={{ borderLeftWidth: "3px" }}
            >
              <span className="small">
                {item.title}
                {item.preliminal && (
                  <span className="ml-1 badge badge-warning">{i18n.preliminal_badge}</span>
                )}
              </span>
              <span className="small font-weight-bold" style={{ whiteSpace: "nowrap" }}>
                {formatAmount(item.amount, d)}
              </span>
            </div>
          ))}
        </div>
      ))}

      {unlinkedFiles.length > 0 && (
        <div className="mb-3">
          <div className="small font-weight-bold text-muted mb-1">
            {i18n.review_dialog_unlinked_files}
          </div>
          {unlinkedFiles.map((f) => (
            <div key={f.id} className="small py-1 pl-2 text-muted">
              {f.filename || `File #${f.id}`}
            </div>
          ))}
        </div>
      )}

      <hr />

      <table className="small w-100 mb-2">
        <tbody>
          <tr>
            <td className="text-muted">{i18n.review_dialog_base_fee}</td>
            <td className="text-right font-weight-bold">{formatAmount(calcData.total_fee, d)}</td>
          </tr>
          <tr>
            <td className="text-muted">{i18n.review_dialog_total_expense}</td>
            <td className="text-right font-weight-bold">{formatAmount(report.total_amount, d)}</td>
          </tr>
          <tr>
            <td className="text-muted">{i18n.review_dialog_remaining}</td>
            <td
              className="text-right font-weight-bold"
              style={{ color: remaining >= 0 ? "#28a745" : "#dc3545" }}
            >
              {formatAmount(remaining.toString(), d)}
            </td>
          </tr>
        </tbody>
      </table>

      {remaining < 0 && (
        <div className="alert alert-warning small py-2 mb-3">
          {i18n.review_dialog_overage_warning}
        </div>
      )}

      <div className="d-flex justify-content-end" style={{ gap: "0.5rem" }}>
        <button
          className="btn btn-outline-secondary btn-sm"
          onClick={onCancel}
          disabled={submitting}
        >
          {i18n.review_dialog_cancel}
        </button>
        <button className="btn btn-primary btn-sm" onClick={onConfirm} disabled={submitting}>
          {submitting ? i18n.submitting : i18n.submit}
        </button>
      </div>
    </dialog>
  );
}
