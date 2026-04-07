import { useState, useEffect, useRef, type RefObject } from "react";
import type { ExpenseLineItem, ExpenseReport, CalculateResponse, TaxMode } from "./types";
import { updateLineItem, deleteLineItem, createLineItem } from "./api";
import { DropZoneIndicator } from "./FileDropOverlay";
import { useI18n, splitAt } from "./I18nContext";

type LineItemFormProps = {
  item: ExpenseLineItem;
  report: ExpenseReport;
  calcData: CalculateResponse | null;
  isReadOnly: boolean;
  lineItemsUrl: string;
  filesUrl: string;
  onUpdate: (r: ExpenseReport) => void;
  onError: (e: string) => void;
  onPreviewFile: (id: number | null) => void;
  onSelectItem: (id: number) => void;
  isDirtyRef: RefObject<boolean>;
  onUploadLinked: (files: File[]) => void;
  isDragging: boolean;
  isDropTarget: boolean;
  linkedEnabled: boolean;
  dropLabel: string;
  isMobile: boolean;
};

function deriveTaxMode(item: ExpenseLineItem): TaxMode {
  if (item.tax_rate === null) return "manual";
  if (parseFloat(item.tax_rate) === 0) return "exempt";
  return "exclude";
}

export function LineItemForm({
  item,
  report,
  calcData,
  isReadOnly,
  lineItemsUrl,
  filesUrl,
  onUpdate,
  onError,
  onPreviewFile,
  onSelectItem,
  isDirtyRef,
  onUploadLinked,
  isDragging,
  isDropTarget,
  linkedEnabled,
  dropLabel,
  isMobile,
}: LineItemFormProps) {
  const i18n = useI18n();
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

  const decimal = calcData?.decimal ?? 0;
  const floorToDecimal = (v: number): string => {
    const factor = 10 ** decimal;
    return (Math.floor(v * factor) / factor).toFixed(decimal);
  };

  const amountDirty = (() => {
    if (taxMode === "include" && taxRate !== null) {
      // enteredAmount is tax-inclusive; item.amount is net — derive net
      // with the same rounding as computeNetAndTax to compare
      const entered = parseFloat(enteredAmount) || 0;
      const rate = parseFloat(taxRate) || 0;
      const net = floorToDecimal(entered / (1 + rate));
      return !numeq(net, item.amount);
    }
    return !numeq(enteredAmount, item.amount);
  })();

  // "include" and "exclude" are UI-only input modes — the server stores
  // the same data (net amount + tax_rate + tax_amount) for both. Treat
  // them as equivalent when checking for unsaved changes.
  const taxModeDirty = (() => {
    const saved = deriveTaxMode(item);
    if (taxMode === saved) return false;
    // "include" ↔ "exclude" is not a real change
    if (
      (taxMode === "include" || taxMode === "exclude") &&
      (saved === "include" || saved === "exclude")
    )
      return false;
    return true;
  })();

  const isDirty =
    title !== item.title ||
    (notes || "") !== (item.notes || "") ||
    amountDirty ||
    preliminal !== item.preliminal ||
    fileIds.join(",") !== item.file_ids.join(",") ||
    taxModeDirty ||
    (taxMode !== "manual" && taxMode !== "exempt" && taxRate !== item.tax_rate) ||
    (taxMode === "manual" && !numeq(taxAmount, item.tax_amount));

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
  }, [item.id, item.file_ids.join(",")]);

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

  const amountStep = decimal > 0 ? (10 ** -decimal).toString() : "1";

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

  const saveCurrentItem = async () => {
    const { netAmount, taxAmt, rate } = computeNetAndTax();
    return updateLineItem(lineItemsUrl, item.id, {
      title,
      notes: notes || null,
      amount: netAmount,
      tax_rate: rate,
      tax_amount: taxAmt,
      preliminal,
      file_ids: fileIds,
    });
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      const result = await saveCurrentItem();
      onUpdate(result);
    } catch (e) {
      onError(e instanceof Error ? e.message : i18n.error_save);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!confirm(i18n.confirm_delete_item)) return;
    setDeleting(true);
    try {
      const result = await deleteLineItem(lineItemsUrl, item.id);
      onUpdate(result);
    } catch (e) {
      onError(e instanceof Error ? e.message : i18n.error_delete);
    } finally {
      setDeleting(false);
    }
  };

  const handleAddMore = async () => {
    setAddingMore(true);
    try {
      if (isDirty) await saveCurrentItem();
      const result = await createLineItem(lineItemsUrl, {
        title: "New expense",
        amount: "0",
        tax_amount: "0",
        file_ids: fileIds,
      });
      onUpdate(result);
      const newItem = result.line_items[result.line_items.length - 1];
      if (newItem) onSelectItem(newItem.id);
    } catch (e) {
      onError(e instanceof Error ? e.message : i18n.error_add);
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
      data-drop-zone="linked"
      className="p-3"
      style={{
        flex: isMobile ? "1 1 auto" : "4 0 0",
        minWidth: isMobile ? undefined : "250px",
        overflow: "auto",
        position: "relative",
      }}
      onSubmit={(e) => {
        e.preventDefault();
        if (isDirty && !saving) handleSave();
      }}
    >
      <div className="form-group">
        <label className="small font-weight-bold" htmlFor={`eli-title-${item.id}`}>
          {i18n.title_label}
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
          {i18n.notes_label}
        </label>
        <textarea
          id={`eli-notes-${item.id}`}
          className="form-control form-control-sm"
          rows={2}
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          disabled={isReadOnly}
          placeholder={i18n.notes_placeholder}
        />
      </div>

      <div className="form-group">
        <label className="small font-weight-bold" htmlFor={`eli-taxmode-${item.id}`}>
          {i18n.tax_mode_label}
        </label>
        <select
          id={`eli-taxmode-${item.id}`}
          className="form-control form-control-sm"
          value={taxMode}
          onChange={(e) => handleTaxModeChange(e.target.value as TaxMode)}
          disabled={isReadOnly}
        >
          <option value="exclude">{i18n.tax_mode_exclude}</option>
          <option value="include">{i18n.tax_mode_include}</option>
          <option value="exempt">{i18n.tax_mode_exempt}</option>
          <option value="manual">{i18n.tax_mode_manual}</option>
        </select>
      </div>

      {(taxMode === "exclude" || taxMode === "include") && (
        <div className="form-group">
          <label className="small font-weight-bold" htmlFor={`eli-taxrate-${item.id}`}>
            {i18n.tax_rate_label}
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
            {taxMode === "include" ? i18n.amount_incl : i18n.amount_excl}
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
              {i18n.tax_amount_label}
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
          {i18n.preliminal_label}
        </label>
      </div>

      <div className="mb-2">
        <label className="small font-weight-bold">{i18n.attached_files}</label>
        {attachedFiles.length > 0 ? (
          <ul className="list-unstyled mb-1">
            {attachedFiles.map((f) => (
              <li
                key={f.id}
                className="d-flex justify-content-between align-items-center small py-1"
              >
                <span
                  style={{ cursor: "pointer" }}
                  onClick={() => {
                    if (isMobile) {
                      window.open(`${filesUrl}/${f.id}`, "_blank");
                    } else {
                      onPreviewFile(f.id);
                    }
                  }}
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
          <div className="small text-muted">{i18n.no_files_attached}</div>
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
              {saving ? i18n.saving : i18n.save}
            </button>
            <button
              className="btn btn-outline-secondary btn-sm"
              onClick={handleAddMore}
              disabled={addingMore}
            >
              {addingMore ? i18n.adding : i18n.add_same_files}
            </button>
          </div>
          <button
            className="btn btn-outline-danger btn-sm"
            onClick={handleDelete}
            disabled={deleting}
          >
            {deleting ? i18n.deleting : i18n.delete}
          </button>
        </div>
      )}
      <DropZoneIndicator
        visible={isDragging}
        highlighted={isDropTarget}
        label={dropLabel}
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
  const i18n = useI18n();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const uploadLink = (
    <a
      href="#"
      onClick={(e) => {
        e.preventDefault();
        fileInputRef.current?.click();
      }}
    >
      {i18n.upload}
    </a>
  );

  return (
    <div
      className="text-muted small text-center mt-1"
      style={{ border: "1px dashed #ccc", borderRadius: "4px", padding: "6px 8px" }}
    >
      <div>
        {(() => {
          const [before, after] = splitAt(i18n.drop_or_upload, "link");
          return (
            <>
              {before}
              {uploadLink}
              {after}
            </>
          );
        })()}
      </div>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/jpeg,image/png,image/gif,image/webp,application/pdf"
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
          <div className="my-1">{i18n.or_separator}</div>
          <select
            className="form-control form-control-sm"
            value=""
            onChange={(e) => {
              const fid = parseInt(e.target.value, 10);
              if (fid) onAttachFile(fid);
            }}
          >
            <option value="">{i18n.link_existing}</option>
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
