import React, { useState, useRef } from "react";
import type { ExpenseReport } from "./types";
import { createLineItem, updateLineItem } from "./api";
import { SortableLineItemList } from "./SortableLineItemList";

type LeftPaneProps = {
  report: ExpenseReport;
  selectedItemId: number | null;
  selectedFileId: number | null;
  onSelectItem: (id: number | null) => void;
  onSelectFile: (id: number | null) => void;
  isReadOnly: boolean;
  lineItemsUrl: string;
  opts: { csrfToken: string };
  onUpdate: (r: ExpenseReport) => void;
  onError: (e: string) => void;
  onUploadFiles: (files: File[]) => void;
};

export function LeftPane({
  report,
  selectedItemId,
  selectedFileId,
  onSelectItem,
  onSelectFile,
  isReadOnly,
  lineItemsUrl,
  opts,
  onUpdate,
  onError,
  onUploadFiles,
}: LeftPaneProps) {
  const [adding, setAdding] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const linkedFileIds = new Set(report.line_items.flatMap((item) => item.file_ids));
  const unlinkedFiles = report.files.filter((f) => !linkedFileIds.has(f.id));

  const handleReorder = async (activeId: number, overId: number) => {
    const items = [...report.line_items];
    const activeIdx = items.findIndex((i) => i.id === activeId);
    const overIdx = items.findIndex((i) => i.id === overId);
    if (activeIdx < 0 || overIdx < 0) return;

    const newPosition = items[overIdx].position;
    try {
      const result = await updateLineItem(lineItemsUrl, activeId, { position: newPosition }, opts);
      onUpdate(result);
    } catch (e) {
      onError(e instanceof Error ? e.message : "Failed to reorder");
    }
  };

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

  const handleFileInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    if (files.length > 0) onUploadFiles(files);
    e.target.value = "";
  };

  return (
    <div
      className="border-right d-flex flex-column"
      style={{ flex: "3 0 0", minWidth: "200px", overflow: "auto" }}
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
      <div className="flex-grow-1" style={{ overflow: "auto", minHeight: "80px" }}>
        <SortableLineItemList
          items={report.line_items}
          selectedItemId={selectedItemId}
          onSelectItem={onSelectItem}
          onReorder={handleReorder}
          disabled={isReadOnly}
        />
        {report.line_items.length === 0 && (
          <div className="p-2 text-muted small">No line items yet</div>
        )}
      </div>

      <div className="p-2 bg-light border-top border-bottom">
        <strong className="small">Files</strong>
      </div>
      <div style={{ flex: "0 1 auto", overflow: "auto", maxHeight: "40%" }}>
        {unlinkedFiles.map((file) => (
          <div
            key={file.id}
            className={`p-2 border-bottom small ${selectedFileId === file.id ? "bg-primary text-white" : ""}`}
            style={{ cursor: "pointer" }}
            onClick={() => onSelectFile(file.id)}
          >
            {file.filename || `File #${file.id}`}
          </div>
        ))}
        {!isReadOnly && (
          <div
            className="p-2 text-muted small text-center"
            style={{ border: "1px dashed #ccc", borderRadius: "4px", margin: "4px" }}
          >
            Drop files to add or{" "}
            <a
              href="#"
              onClick={(e) => {
                e.preventDefault();
                fileInputRef.current?.click();
              }}
            >
              upload
            </a>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/jpeg,image/png,image/webp,application/pdf"
              multiple
              className="d-none"
              onChange={handleFileInputChange}
            />
          </div>
        )}
      </div>
    </div>
  );
}
