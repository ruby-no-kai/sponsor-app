import React, { useState } from "react";
import type { ExpenseReport, ExpenseFile } from "./types";
import { createLineItem } from "./api";

type LeftPaneProps = {
  report: ExpenseReport;
  selectedItemId: number | null;
  onSelectItem: (id: number | null) => void;
  onSelectFile: (id: number | null) => void;
  isReadOnly: boolean;
  lineItemsUrl: string;
  opts: { csrfToken: string };
  onUpdate: (r: ExpenseReport) => void;
  onError: (e: string) => void;
};

export function LeftPane({
  report,
  selectedItemId,
  onSelectItem,
  onSelectFile,
  isReadOnly,
  lineItemsUrl,
  opts,
  onUpdate,
  onError,
}: LeftPaneProps) {
  const [adding, setAdding] = useState(false);

  const linkedFileIds = new Set(
    report.line_items.flatMap((item) => item.file_ids),
  );
  const unlinkedFiles = report.files.filter((f) => !linkedFileIds.has(f.id));

  const handleAddItem = async () => {
    setAdding(true);
    try {
      const result = await createLineItem(
        lineItemsUrl,
        { title: "New expense", amount: "0", tax_amount: "0" },
        opts,
      );
      onUpdate(result);
      const newItem = result.line_items[result.line_items.length - 1];
      if (newItem) onSelectItem(newItem.id);
    } catch (e) {
      onError(e instanceof Error ? e.message : "Failed to add item");
    } finally {
      setAdding(false);
    }
  };

  return (
    <div
      className="border-right d-flex flex-column"
      style={{ width: "250px", minWidth: "250px", overflow: "auto" }}
    >
      <div className="p-2 bg-light border-bottom d-flex justify-content-between align-items-center">
        <strong className="small">Line Items</strong>
        {!isReadOnly && (
          <button
            className="btn btn-sm btn-outline-primary"
            onClick={handleAddItem}
            disabled={adding}
            title="Add line item"
          >
            +
          </button>
        )}
      </div>
      <div className="flex-grow-1" style={{ overflow: "auto" }}>
        {report.line_items.map((item) => (
          <div
            key={item.id}
            className={`p-2 border-bottom cursor-pointer ${selectedItemId === item.id ? "bg-primary text-white" : ""}`}
            style={{ cursor: "pointer" }}
            onClick={() => onSelectItem(item.id)}
          >
            <div className="small font-weight-bold text-truncate">
              {item.title}
            </div>
            <div className="small">
              {formatAmount(item.amount)}
              {item.preliminal && (
                <span
                  className={`ml-1 badge ${selectedItemId === item.id ? "badge-light" : "badge-warning"}`}
                >
                  preliminal
                </span>
              )}
            </div>
          </div>
        ))}
        {report.line_items.length === 0 && (
          <div className="p-2 text-muted small">No line items yet</div>
        )}
      </div>

      {unlinkedFiles.length > 0 && (
        <>
          <div className="p-2 bg-light border-top border-bottom">
            <strong className="small">Unlinked Files</strong>
          </div>
          <div style={{ overflow: "auto", maxHeight: "150px" }}>
            {unlinkedFiles.map((file) => (
              <div
                key={file.id}
                className="p-2 border-bottom small"
                style={{ cursor: "pointer" }}
                onClick={() => onSelectFile(file.id)}
              >
                {file.filename || `File #${file.id}`}
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

function formatAmount(amount: string): string {
  const num = parseFloat(amount);
  return isNaN(num) ? amount : num.toLocaleString();
}
