import React, { useState, useEffect, type RefObject } from "react";
import type { ExpenseLineItem, ExpenseReport, CalculateResponse, TaxMode } from "./types";
import { updateLineItem, deleteLineItem } from "./api";

type CenterPaneProps = {
  item: ExpenseLineItem | null;
  selectedFile: ExpenseReport["files"][number] | null;
  report: ExpenseReport;
  calcData: CalculateResponse | null;
  isReadOnly: boolean;
  lineItemsUrl: string;
  filesUrl: string;
  opts: { csrfToken: string };
  onUpdate: (r: ExpenseReport) => void;
  onError: (e: string) => void;
  onPreviewFile: (id: number | null) => void;
  onSelectItem: (id: number) => void;
  onRefresh: () => void;
  isDirtyRef: RefObject<boolean>;
};

function deriveTaxMode(item: ExpenseLineItem): TaxMode {
  if (item.tax_rate === null) return "manual";
  if (parseFloat(item.tax_rate) === 0) return "exempt";
  return "exclude";
}

export function CenterPane({
  item,
  selectedFile,
  report,
  calcData,
  isReadOnly,
  lineItemsUrl,
  filesUrl,
  opts,
  onUpdate,
  onError,
  onPreviewFile,
  onSelectItem,
  onRefresh,
  isDirtyRef,
}: CenterPaneProps) {
  const [title, setTitle] = useState("");
  const [notes, setNotes] = useState("");
  const [amount, setAmount] = useState("");
  const [taxRate, setTaxRate] = useState<string | null>(null);
  const [taxAmount, setTaxAmount] = useState("");
  const [preliminal, setPreliminal] = useState(false);
  const [taxMode, setTaxMode] = useState<TaxMode>("exclude");
  const [enteredAmount, setEnteredAmount] = useState("");
  const [fileIds, setFileIds] = useState<number[]>([]);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const isDirty = item
    ? title !== item.title ||
      (notes || "") !== (item.notes || "") ||
      enteredAmount !== item.amount ||
      preliminal !== item.preliminal ||
      fileIds.join() !== item.file_ids.join() ||
      taxMode !== deriveTaxMode(item) ||
      (taxMode !== "manual" && taxMode !== "exempt" && taxRate !== item.tax_rate) ||
      (taxMode === "manual" && taxAmount !== item.tax_amount)
    : false;

  // Expose isDirty to parent via ref
  useEffect(() => {
    if (isDirtyRef) isDirtyRef.current = isDirty;
  }, [isDirty]);

  useEffect(() => {
    if (!item) return;
    setTitle(item.title);
    setNotes(item.notes || "");
    setAmount(item.amount);
    setTaxRate(item.tax_rate);
    setTaxAmount(item.tax_amount);
    setPreliminal(item.preliminal);
    setFileIds(item.file_ids);

    const mode = deriveTaxMode(item);
    setTaxMode(mode);
    setEnteredAmount(item.amount);
  }, [item?.id, item?.file_ids.join()]);

  const [creatingFromFile, setCreatingFromFile] = useState(false);
  const [deletingFile, setDeletingFile] = useState(false);

  const handleDeleteFile = async () => {
    if (!selectedFile || !confirm("Delete this file?")) return;
    setDeletingFile(true);
    try {
      const { deleteFile } = await import("./api");
      await deleteFile(filesUrl, selectedFile.id, opts);
      onPreviewFile(null);
      onRefresh();
    } catch (e) {
      onError(e instanceof Error ? e.message : "Failed to delete");
    } finally {
      setDeletingFile(false);
    }
  };

  const handleCreateFromFile = async () => {
    if (!selectedFile) return;
    setCreatingFromFile(true);
    try {
      const { createLineItem } = await import("./api");
      const result = await createLineItem(
        lineItemsUrl,
        {
          title: selectedFile.filename || "New expense",
          amount: "0",
          tax_amount: "0",
          file_ids: [selectedFile.id],
        },
        opts,
      );
      onUpdate(result);
      const newItem = result.line_items[result.line_items.length - 1];
      if (newItem) onSelectItem(newItem.id);
    } catch (e) {
      onError(e instanceof Error ? e.message : "Failed to create");
    } finally {
      setCreatingFromFile(false);
    }
  };

  if (!item) {
    return (
      <div
        className="flex-grow-1 d-flex flex-column align-items-center justify-content-center text-muted"
        style={{ overflow: "auto" }}
      >
        {selectedFile && !isReadOnly ? (
          <div className="text-center">
            <p className="mb-2 small">{selectedFile.filename}</p>
            <button
              className="btn btn-primary btn-sm mb-2"
              onClick={handleCreateFromFile}
              disabled={creatingFromFile}
            >
              {creatingFromFile ? "Creating..." : "Create line item from this file"}
            </button>
            <br />
            <button
              className="btn btn-outline-danger btn-sm"
              onClick={handleDeleteFile}
              disabled={deletingFile}
            >
              {deletingFile ? "Deleting..." : "Delete this file"}
            </button>
          </div>
        ) : (
          "Select a line item"
        )}
      </div>
    );
  }

  const taxRates = calcData?.tax_rates || [];

  const handleTaxModeChange = (newMode: TaxMode) => {
    setTaxMode(newMode);
    if (newMode === "exempt") {
      setTaxRate("0");
      setTaxAmount("0");
    } else if (newMode === "manual") {
      setTaxRate(null);
    } else if (newMode === "exclude" || newMode === "include") {
      const rate = taxRates[0] || "0.1";
      setTaxRate(rate);
    }
  };

  const computeNetAndTax = (): { netAmount: string; taxAmt: string; rate: string | null } => {
    const entered = parseFloat(enteredAmount) || 0;
    if (taxMode === "exempt") {
      return { netAmount: enteredAmount, taxAmt: "0", rate: "0" };
    }
    if (taxMode === "manual") {
      return { netAmount: enteredAmount, taxAmt: taxAmount, rate: null };
    }
    const rate = parseFloat(taxRate || "0.1");
    if (taxMode === "include") {
      const net = entered / (1 + rate);
      const tax = entered - net;
      return {
        netAmount: net.toFixed(2),
        taxAmt: tax.toFixed(2),
        rate: rate.toString(),
      };
    }
    // exclude
    const tax = entered * rate;
    return {
      netAmount: enteredAmount,
      taxAmt: tax.toFixed(2),
      rate: rate.toString(),
    };
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      const { netAmount, taxAmt, rate } = computeNetAndTax();
      const result = await updateLineItem(
        lineItemsUrl,
        item.id,
        {
          title,
          notes: notes || null,
          amount: netAmount,
          tax_rate: rate,
          tax_amount: taxAmt,
          preliminal,
          file_ids: fileIds,
        },
        opts,
      );
      onUpdate(result);
    } catch (e) {
      onError(e instanceof Error ? e.message : "Failed to save");
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!confirm("Delete this line item?")) return;
    setDeleting(true);
    try {
      const result = await deleteLineItem(lineItemsUrl, item.id, opts);
      onUpdate(result);
    } catch (e) {
      onError(e instanceof Error ? e.message : "Failed to delete");
    } finally {
      setDeleting(false);
    }
  };

  const handleRemoveFile = (fid: number) => {
    setFileIds(fileIds.filter((id) => id !== fid));
  };

  const handleAttachFile = (fid: number) => {
    if (!fileIds.includes(fid)) {
      setFileIds([...fileIds, fid]);
    }
  };

  const attachableFiles = report.files.filter((f) => !fileIds.includes(f.id));
  const attachedFiles = report.files.filter((f) => fileIds.includes(f.id));

  return (
    <div className="flex-grow-1 p-3" style={{ overflow: "auto", minWidth: 0 }}>
      <div className="form-group">
        <label className="small font-weight-bold">Title</label>
        <input
          type="text"
          className="form-control form-control-sm"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          disabled={isReadOnly}
        />
      </div>

      <div className="form-group">
        <label className="small font-weight-bold">Notes</label>
        <textarea
          className="form-control form-control-sm"
          rows={2}
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          disabled={isReadOnly}
        />
      </div>

      <div className="form-group">
        <label className="small font-weight-bold">Tax mode</label>
        <select
          className="form-control form-control-sm"
          value={taxMode}
          onChange={(e) => handleTaxModeChange(e.target.value as TaxMode)}
          disabled={isReadOnly}
        >
          <option value="exclude">Entered amount excludes tax</option>
          <option value="include">Entered amount includes tax</option>
          <option value="exempt">Tax does not apply</option>
          <option value="manual">Enter amounts manually</option>
        </select>
      </div>

      {(taxMode === "exclude" || taxMode === "include") && (
        <div className="form-group">
          <label className="small font-weight-bold">Tax rate</label>
          <select
            className="form-control form-control-sm"
            value={taxRate || ""}
            onChange={(e) => setTaxRate(e.target.value)}
            disabled={isReadOnly}
          >
            {taxRates.map((rate) => (
              <option key={rate} value={rate}>
                {(parseFloat(rate) * 100).toFixed(0)}%
              </option>
            ))}
          </select>
        </div>
      )}

      <div className="form-row">
        <div className="form-group col">
          <label className="small font-weight-bold">
            Amount {taxMode === "include" ? "(incl. tax)" : "(excl. tax)"}
          </label>
          <input
            type="number"
            className="form-control form-control-sm"
            step="0.01"
            min="0"
            value={enteredAmount}
            onChange={(e) => setEnteredAmount(e.target.value)}
            disabled={isReadOnly}
          />
        </div>
        {taxMode === "manual" && (
          <div className="form-group col">
            <label className="small font-weight-bold">Tax amount</label>
            <input
              type="number"
              className="form-control form-control-sm"
              step="0.01"
              min="0"
              value={taxAmount}
              onChange={(e) => setTaxAmount(e.target.value)}
              disabled={isReadOnly}
            />
          </div>
        )}
      </div>

      <div className="form-group form-check">
        <input
          type="checkbox"
          className="form-check-input"
          id={`preliminal-${item.id}`}
          checked={preliminal}
          onChange={(e) => setPreliminal(e.target.checked)}
          disabled={isReadOnly}
        />
        <label className="form-check-label small" htmlFor={`preliminal-${item.id}`}>
          Preliminal (planned budget, not finalized)
        </label>
      </div>

      <div className="mb-2">
        <label className="small font-weight-bold">Attached files</label>
        {attachedFiles.length > 0 ? (
          <ul className="list-unstyled mb-1">
            {attachedFiles.map((f) => (
              <li
                key={f.id}
                className="d-flex justify-content-between align-items-center small py-1"
              >
                <span
                  style={{ cursor: "pointer" }}
                  onClick={() => onPreviewFile(f.id)}
                  className="text-primary"
                >
                  {f.filename || `File #${f.id}`}
                </span>
                {!isReadOnly && (
                  <button
                    className="btn btn-sm btn-link text-danger p-0"
                    onClick={() => handleRemoveFile(f.id)}
                  >
                    &times;
                  </button>
                )}
              </li>
            ))}
          </ul>
        ) : (
          <div className="small text-muted">No files attached</div>
        )}
        {!isReadOnly && attachableFiles.length > 0 && (
          <select
            className="form-control form-control-sm mt-1"
            value=""
            onChange={(e) => {
              const fid = parseInt(e.target.value, 10);
              if (fid) handleAttachFile(fid);
            }}
          >
            <option value="">Attach a file...</option>
            {attachableFiles.map((f) => (
              <option key={f.id} value={f.id}>
                {f.filename || `File #${f.id}`}
              </option>
            ))}
          </select>
        )}
        {!isReadOnly && (
          <div
            className="text-muted small text-center mt-1"
            style={{ border: "1px dashed #ccc", borderRadius: "4px", padding: "4px" }}
          >
            Drop files here to attach
          </div>
        )}
      </div>

      {!isReadOnly && (
        <div className="d-flex justify-content-between mt-3">
          <button
            className="btn btn-primary btn-sm"
            onClick={handleSave}
            disabled={saving || !isDirty}
          >
            {saving ? "Saving..." : "Save"}
          </button>
          <button
            className="btn btn-outline-danger btn-sm"
            onClick={handleDelete}
            disabled={deleting}
          >
            {deleting ? "Deleting..." : "Delete"}
          </button>
        </div>
      )}
    </div>
  );
}
