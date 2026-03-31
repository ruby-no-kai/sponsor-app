import React, { useState, useEffect, useRef, type RefObject } from "react";
import type { ExpenseLineItem, ExpenseReport, CalculateResponse, TaxMode } from "./types";
import { updateLineItem, deleteLineItem } from "./api";
import { DropZoneIndicator } from "./FileDropOverlay";

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
  onUploadLinked: (files: File[]) => void;
  isDragging: boolean;
  isDropTarget: boolean;
  linkedEnabled: boolean;
  selectedItemTitle: string | null;
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
  onUploadLinked,
  isDragging,
  isDropTarget,
  linkedEnabled,
  selectedItemTitle,
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
  const [addingMore, setAddingMore] = useState(false);

  const numeq = (a: string, b: string) => (parseFloat(a) || 0) === (parseFloat(b) || 0);

  const isDirty = item
    ? title !== item.title ||
      (notes || "") !== (item.notes || "") ||
      !numeq(enteredAmount, item.amount) ||
      preliminal !== item.preliminal ||
      fileIds.join() !== item.file_ids.join() ||
      taxMode !== deriveTaxMode(item) ||
      (taxMode !== "manual" && taxMode !== "exempt" && taxRate !== item.tax_rate) ||
      (taxMode === "manual" && !numeq(taxAmount, item.tax_amount))
    : false;

  // Expose isDirty to parent via ref
  useEffect(() => {
    if (isDirtyRef) isDirtyRef.current = isDirty;
  }, [isDirty]);

  const formatForInput = (v: string): string => {
    const num = parseFloat(v);
    if (isNaN(num)) return v;
    const d = calcData?.decimal ?? 0;
    return num.toFixed(d);
  };

  useEffect(() => {
    if (!item) return;
    setTitle(item.title);
    setNotes(item.notes || "");
    setAmount(item.amount);
    setTaxRate(item.tax_rate);
    setTaxAmount(formatForInput(item.tax_amount));
    setPreliminal(item.preliminal);
    setFileIds(item.file_ids);

    const mode = deriveTaxMode(item);
    setTaxMode(mode);
    setEnteredAmount(formatForInput(item.amount));
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
        className="d-flex flex-column align-items-center justify-content-center text-muted"
        style={{ flex: "4 0 0", minWidth: "250px", overflow: "auto", position: "relative" }}
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
        <DropZoneIndicator
          visible={isDragging}
          highlighted={isDropTarget}
          label={selectedItemTitle ? `Link to "${selectedItemTitle}"` : "Create new line item"}
          enabled={linkedEnabled}
        />
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

  const decimal = calcData?.decimal ?? 0;
  const amountStep = decimal > 0 ? (10 ** -decimal).toString() : "1";

  const floorToDecimal = (v: number): string => {
    const factor = 10 ** decimal;
    return (Math.floor(v * factor) / factor).toFixed(decimal);
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
        netAmount: floorToDecimal(net),
        taxAmt: floorToDecimal(tax),
        rate: rate.toString(),
      };
    }
    // exclude
    const tax = entered * rate;
    return {
      netAmount: enteredAmount,
      taxAmt: floorToDecimal(tax),
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

  const handleAddMore = async () => {
    setAddingMore(true);
    try {
      const { createLineItem } = await import("./api");
      const result = await createLineItem(
        lineItemsUrl,
        { title: "New expense", amount: "0", tax_amount: "0", file_ids: fileIds },
        opts,
      );
      onUpdate(result);
      const newItem = result.line_items[result.line_items.length - 1];
      if (newItem) onSelectItem(newItem.id);
    } catch (e) {
      onError(e instanceof Error ? e.message : "Failed to add");
    } finally {
      setAddingMore(false);
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
    <form
      className="p-3"
      style={{ flex: "4 0 0", minWidth: "250px", overflow: "auto", position: "relative" }}
      onSubmit={(e) => {
        e.preventDefault();
        if (isDirty && !saving) handleSave();
      }}
    >
      <div className="form-group">
        <label className="small font-weight-bold" htmlFor={`eli-title-${item.id}`}>
          Title
        </label>
        <input
          id={`eli-title-${item.id}`}
          type="text"
          className="form-control form-control-sm"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          disabled={isReadOnly}
        />
      </div>

      <div className="form-group">
        <label className="small font-weight-bold" htmlFor={`eli-notes-${item.id}`}>
          Notes
        </label>
        <textarea
          id={`eli-notes-${item.id}`}
          className="form-control form-control-sm"
          rows={2}
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          disabled={isReadOnly}
          placeholder="(optional)"
        />
      </div>

      <div className="form-group">
        <label className="small font-weight-bold" htmlFor={`eli-taxmode-${item.id}`}>
          Tax mode
        </label>
        <select
          id={`eli-taxmode-${item.id}`}
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
          <label className="small font-weight-bold" htmlFor={`eli-taxrate-${item.id}`}>
            Tax rate
          </label>
          <select
            id={`eli-taxrate-${item.id}`}
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
          <label className="small font-weight-bold" htmlFor={`eli-amount-${item.id}`}>
            Amount {taxMode === "include" ? "(incl. tax)" : "(excl. tax)"}
          </label>
          <input
            id={`eli-amount-${item.id}`}
            type="number"
            className="form-control form-control-sm"
            step={amountStep}
            min="0"
            value={enteredAmount}
            onChange={(e) => setEnteredAmount(e.target.value)}
            disabled={isReadOnly}
          />
        </div>
        {taxMode === "manual" && (
          <div className="form-group col">
            <label className="small font-weight-bold" htmlFor={`eli-taxamt-${item.id}`}>
              Tax amount
            </label>
            <input
              id={`eli-taxamt-${item.id}`}
              type="number"
              className="form-control form-control-sm"
              step={amountStep}
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
        {!isReadOnly && (
          <AttachFileBox
            attachableFiles={attachableFiles}
            onAttachFile={handleAttachFile}
            onUploadFiles={onUploadLinked}
          />
        )}
      </div>

      {!isReadOnly && (
        <div className="d-flex justify-content-between mt-3">
          <div>
            <button
              className="btn btn-primary btn-sm mr-1"
              onClick={handleSave}
              disabled={saving || !isDirty}
            >
              {saving ? "Saving..." : "Save"}
            </button>
            <button
              className="btn btn-outline-secondary btn-sm"
              onClick={handleAddMore}
              disabled={addingMore || isDirty}
            >
              {addingMore ? "Adding..." : "Add line with the same files"}
            </button>
          </div>
          <button
            className="btn btn-outline-danger btn-sm"
            onClick={handleDelete}
            disabled={deleting}
          >
            {deleting ? "Deleting..." : "Delete"}
          </button>
        </div>
      )}
      <DropZoneIndicator
        visible={isDragging}
        highlighted={isDropTarget}
        label={selectedItemTitle ? `Link to "${selectedItemTitle}"` : "Create new line item"}
        enabled={linkedEnabled}
      />
    </form>
  );
}

function AttachFileBox({
  attachableFiles,
  onAttachFile,
  onUploadFiles,
}: {
  attachableFiles: { id: number; filename: string }[];
  onAttachFile: (id: number) => void;
  onUploadFiles: (files: File[]) => void;
}) {
  const fileInputRef = useRef<HTMLInputElement>(null);

  return (
    <div
      className="text-muted small text-center mt-1"
      style={{ border: "1px dashed #ccc", borderRadius: "4px", padding: "6px 8px" }}
    >
      <div>
        Drop files here or{" "}
        <a
          href="#"
          onClick={(e) => {
            e.preventDefault();
            fileInputRef.current?.click();
          }}
        >
          upload
        </a>{" "}
        to attach
      </div>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp,application/pdf"
        multiple
        className="d-none"
        onChange={(e) => {
          const files = Array.from(e.target.files || []);
          if (files.length > 0) onUploadFiles(files);
          e.target.value = "";
        }}
      />
      {attachableFiles.length > 0 && (
        <>
          <div className="my-1">&mdash; or &mdash;</div>
          <select
            className="form-control form-control-sm"
            value=""
            onChange={(e) => {
              const fid = parseInt(e.target.value, 10);
              if (fid) onAttachFile(fid);
            }}
          >
            <option value="">Link existing file...</option>
            {attachableFiles.map((f) => (
              <option key={f.id} value={f.id}>
                {f.filename || `File #${f.id}`}
              </option>
            ))}
          </select>
        </>
      )}
    </div>
  );
}
