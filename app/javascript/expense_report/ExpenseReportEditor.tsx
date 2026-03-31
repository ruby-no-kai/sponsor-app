import React, { useState, useEffect, useCallback, useRef } from "react";
import type { EditorProps, ExpenseReport, CalculateResponse } from "./types";
import { fetchReport, fetchCalculate, submitReport, withdrawSubmission } from "./api";
import { LeftPane } from "./LeftPane";
import { CenterPane } from "./CenterPane";
import { RightPane } from "./RightPane";
import { AdminReviewForm } from "./AdminReviewForm";
import { FileDropOverlay } from "./FileDropOverlay";
import { useFileUpload } from "./useFileUpload";
import { UploadDialog } from "./UploadDialog";
import { useIsMobile } from "./useIsMobile";
import { I18nProvider, useI18n } from "./I18nContext";
import { SubmitReviewDialog } from "./SubmitReviewDialog";
import { formatAmount } from "./format";

export function ExpenseReportEditor(props: EditorProps) {
  return (
    <I18nProvider value={props.i18n}>
      <ExpenseReportEditorInner {...props} />
    </I18nProvider>
  );
}

function ExpenseReportEditorInner(props: EditorProps) {
  const i18n = useI18n();
  const [report, setReport] = useState<ExpenseReport | null>(null);
  const [calcData, setCalcData] = useState<CalculateResponse | null>(null);

  const parseFragment = (): { itemId: number | null; fileId: number | null } => {
    const hash = window.location.hash;
    const itemMatch = hash.match(/^#item-(\d+)$/);
    const fileMatch = hash.match(/^#file-(\d+)$/);
    return {
      itemId: itemMatch ? parseInt(itemMatch[1], 10) : null,
      fileId: fileMatch ? parseInt(fileMatch[1], 10) : null,
    };
  };

  const isMobile = useIsMobile();
  const initialFragment = useRef(parseFragment());
  const [selectedItemId, setSelectedItemId] = useState<number | null>(
    initialFragment.current.itemId,
  );
  const [previewFileId, setPreviewFileId] = useState<number | null>(initialFragment.current.fileId);
  const [mobileView, setMobileView] = useState<"list" | "detail">(() =>
    initialFragment.current.itemId || initialFragment.current.fileId ? "detail" : "list",
  );
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const opts = { csrfToken: props.csrfToken };
  const centerPaneDirtyRef = useRef(false);

  const guardDirty = useCallback((): boolean => {
    if (centerPaneDirtyRef.current) {
      return confirm(i18n.confirm_discard);
    }
    return true;
  }, [i18n.confirm_discard]);

  useEffect(() => {
    if (selectedItemId) {
      history.replaceState(null, "", `#item-${selectedItemId}`);
    } else if (previewFileId) {
      history.replaceState(null, "", `#file-${previewFileId}`);
    } else {
      history.replaceState(null, "", window.location.pathname + window.location.search);
    }
  }, [selectedItemId, previewFileId]);

  const isReadOnly =
    report?.status === "approved" || (props.role === "sponsor" && report?.status === "submitted");

  const refreshReport = useCallback(async () => {
    try {
      const [r, c] = await Promise.all([
        fetchReport(props.reportUrl, opts),
        fetchCalculate(props.calculateUrl, opts),
      ]);
      setReport(r);
      setCalcData(c);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : i18n.error_load);
    } finally {
      setLoading(false);
    }
  }, [props.reportUrl, props.calculateUrl, props.csrfToken]);

  useEffect(() => {
    refreshReport();
  }, [refreshReport]);

  const handleReportUpdate = useCallback((updatedReport: ExpenseReport) => {
    setReport(updatedReport);
    setError(null);
  }, []);

  const { dialogState, startUpload, handleRetry, handleDiscard } = useFileUpload({
    filesUrl: props.filesUrl,
    reportUrl: props.reportUrl,
    lineItemsUrl: props.lineItemsUrl,
    csrfToken: props.csrfToken,
    onReportUpdate: handleReportUpdate,
    onError: setError,
    onSelectItem: (id) => {
      setSelectedItemId(id);
      setPreviewFileId(null);
    },
    onSelectFile: (id) => {
      setPreviewFileId(id);
      setSelectedItemId(null);
    },
  });

  const handleDropUnlinked = useCallback((files: File[]) => startUpload(files), [startUpload]);

  const handleDropLinked = useCallback(
    (files: File[]) => startUpload(files, selectedItemId, !selectedItemId),
    [startUpload, selectedItemId],
  );

  const selectedItem = report?.line_items.find((i) => i.id === selectedItemId);
  const previewFile = report?.files.find((f) => f.id === previewFileId);

  if (loading) {
    return (
      <div className="text-center py-5">
        <p>{i18n.loading}</p>
      </div>
    );
  }

  if (error && !report) {
    return (
      <div className="alert alert-danger" role="alert">
        {error}
      </div>
    );
  }

  if (!report) return null;

  const statusLabels = props.statusLabels;

  const breakoutStyle: React.CSSProperties = isMobile
    ? { width: "100%" }
    : {
        width: "calc(100vw - 180px)",
        marginLeft: "calc(-1 * (100vw - 180px - 100%) / 2)",
      };

  return (
    <div>
      {error && (
        <div className="alert alert-warning alert-dismissible" role="alert">
          {error}
          <button type="button" className="close" onClick={() => setError(null)}>
            <span>&times;</span>
          </button>
        </div>
      )}

      <div
        className={`d-flex mb-2 ${isMobile ? "flex-column" : "justify-content-between align-items-center"}`}
      >
        <div
          className="d-flex align-items-center flex-wrap"
          style={isMobile ? { fontSize: "0.85rem", overflowX: "auto" } : undefined}
        >
          <StatusBadge
            status={report.status}
            label={statusLabels[report.status] || report.status}
          />
          {calcData &&
            (() => {
              const d = calcData.decimal;
              const fee = parseFloat(calcData.total_fee) || 0;
              const expense = parseFloat(report.total_amount) || 0;
              const remaining = fee - expense;
              return (
                <span className="ml-3" style={{ whiteSpace: "nowrap" }}>
                  <span className="text-muted">{i18n.fee}</span>{" "}
                  <strong>{formatAmount(calcData.total_fee, d)}</strong>
                  <span className="text-muted ml-2">{i18n.expense}</span>{" "}
                  <strong>{formatAmount(report.total_amount, d)}</strong>
                  <span className="text-muted"> {i18n.plus_tax} </span>
                  <strong>{formatAmount(report.total_tax_amount, d)}</strong>
                  <span className="text-muted ml-2">{i18n.remaining}</span>{" "}
                  <strong style={{ color: remaining >= 0 ? "#28a745" : "#dc3545" }}>
                    {formatAmount(remaining.toString(), d)}
                  </strong>
                </span>
              );
            })()}
        </div>
        <div>
          {!isReadOnly &&
            props.role === "sponsor" &&
            report.status === "draft" &&
            props.submissionUrl && (
              <SubmitButton
                submissionUrl={props.submissionUrl}
                opts={opts}
                report={report}
                calcData={calcData!}
                onUpdate={handleReportUpdate}
                onError={setError}
              />
            )}
          {props.role === "sponsor" && report.status === "submitted" && props.submissionUrl && (
            <WithdrawButton
              submissionUrl={props.submissionUrl}
              opts={opts}
              onUpdate={handleReportUpdate}
              onError={setError}
            />
          )}
        </div>
      </div>

      {report.latest_review?.action === "reject" && report.latest_review?.comment && (
        <div className="alert alert-danger mb-2">
          <strong>{i18n.review_feedback}</strong> {report.latest_review.comment}
        </div>
      )}

      <div style={breakoutStyle}>
        <FileDropOverlay
          disabled={isReadOnly}
          onDropUnlinked={handleDropUnlinked}
          onDropLinked={handleDropLinked}
          isMobile={isMobile}
          mobileView={mobileView}
        >
          {({ isDragging, hoverZone }) => (
            <div
              className={`${isMobile ? "d-flex flex-column" : "d-flex"} border rounded`}
              style={{
                height: isMobile ? "auto" : "80vh",
                minHeight: isMobile ? "60vh" : undefined,
                overflow: "hidden",
                backgroundColor: "white",
                color: "#212529",
              }}
            >
              {(!isMobile || mobileView === "list") && (
                <LeftPane
                  report={report}
                  selectedItemId={selectedItemId}
                  selectedFileId={!selectedItemId ? previewFileId : null}
                  onSelectItem={(id) => {
                    if (!guardDirty()) return;
                    setSelectedItemId(id);
                    const item = report.line_items.find((i) => i.id === id);
                    setPreviewFileId(item?.file_ids[0] ?? null);
                    if (isMobile) setMobileView("detail");
                  }}
                  onSelectFile={(id) => {
                    if (!guardDirty()) return;
                    setPreviewFileId(id);
                    setSelectedItemId(null);
                    if (isMobile) setMobileView("detail");
                  }}
                  isReadOnly={isReadOnly}
                  lineItemsUrl={props.lineItemsUrl}
                  opts={opts}
                  onUpdate={handleReportUpdate}
                  onError={setError}
                  onUploadFiles={handleDropUnlinked}
                  isDragging={isDragging}
                  isDropTarget={isDragging && hoverZone === "unlinked"}
                  isMobile={isMobile}
                />
              )}
              {(!isMobile || mobileView === "detail") && (
                <>
                  {isMobile && (
                    <div className="p-2 bg-light border-bottom">
                      <button
                        className="btn btn-sm btn-outline-secondary"
                        onClick={() => {
                          if (!guardDirty()) return;
                          setMobileView("list");
                          setSelectedItemId(null);
                          setPreviewFileId(null);
                        }}
                      >
                        &larr; {i18n.back}
                      </button>
                    </div>
                  )}
                  <CenterPane
                    item={selectedItem || null}
                    selectedFile={
                      !selectedItem && previewFileId
                        ? report.files.find((f) => f.id === previewFileId) || null
                        : null
                    }
                    report={report}
                    calcData={calcData}
                    isReadOnly={isReadOnly}
                    lineItemsUrl={props.lineItemsUrl}
                    filesUrl={props.filesUrl}
                    opts={opts}
                    onUpdate={handleReportUpdate}
                    onError={setError}
                    onPreviewFile={setPreviewFileId}
                    onSelectItem={(id) => {
                      setSelectedItemId(id);
                      setPreviewFileId(null);
                    }}
                    onRefresh={refreshReport}
                    isDirtyRef={centerPaneDirtyRef}
                    onUploadLinked={handleDropLinked}
                    isDragging={isDragging}
                    isDropTarget={isDragging && hoverZone === "linked"}
                    linkedEnabled
                    selectedItemTitle={selectedItem?.title || null}
                    isMobile={isMobile}
                  />
                </>
              )}
              {!isMobile && (
                <RightPane
                  file={previewFile || null}
                  filesUrl={props.filesUrl}
                  isDragging={isDragging}
                  isDropTarget={isDragging && hoverZone === "linked"}
                  linkedEnabled
                />
              )}
            </div>
          )}
        </FileDropOverlay>
      </div>

      {props.role === "admin" && props.reviewsUrl && (
        <AdminReviewForm
          report={report}
          reviewsUrl={props.reviewsUrl}
          opts={opts}
          onUpdate={handleReportUpdate}
          onError={setError}
        />
      )}

      <UploadDialog state={dialogState} onRetry={handleRetry} onDiscard={handleDiscard} />
    </div>
  );
}

function StatusBadge({ status, label }: { status: ExpenseReport["status"]; label: string }) {
  const badges: Record<string, string> = {
    draft: "badge-secondary",
    submitted: "badge-info",
    approved: "badge-success",
    rejected: "badge-danger",
  };
  return <span className={`badge ${badges[status] || "badge-light"}`}>{label}</span>;
}

function SubmitButton({
  submissionUrl,
  opts,
  report,
  calcData,
  onUpdate,
  onError,
}: {
  submissionUrl: string;
  opts: { csrfToken: string };
  report: ExpenseReport;
  calcData: CalculateResponse;
  onUpdate: (r: ExpenseReport) => void;
  onError: (e: string) => void;
}) {
  const i18n = useI18n();
  const [showDialog, setShowDialog] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const handleConfirm = async () => {
    setSubmitting(true);
    try {
      const result = await submitReport(submissionUrl, opts);
      setShowDialog(false);
      onUpdate(result);
    } catch (e) {
      onError(e instanceof Error ? e.message : i18n.error_submit);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <button className="btn btn-primary btn-sm" onClick={() => setShowDialog(true)}>
        {i18n.submit}
      </button>
      <SubmitReviewDialog
        open={showDialog}
        report={report}
        calcData={calcData}
        onConfirm={handleConfirm}
        onCancel={() => setShowDialog(false)}
        submitting={submitting}
      />
    </>
  );
}

function WithdrawButton({
  submissionUrl,
  opts,
  onUpdate,
  onError,
}: {
  submissionUrl: string;
  opts: { csrfToken: string };
  onUpdate: (r: ExpenseReport) => void;
  onError: (e: string) => void;
}) {
  const i18n = useI18n();
  const [withdrawing, setWithdrawing] = useState(false);

  const handleWithdraw = async () => {
    if (!confirm(i18n.confirm_withdraw)) return;
    setWithdrawing(true);
    try {
      const result = await withdrawSubmission(submissionUrl, opts);
      onUpdate(result);
    } catch (e) {
      onError(e instanceof Error ? e.message : i18n.error_withdraw);
    } finally {
      setWithdrawing(false);
    }
  };

  return (
    <button className="btn btn-warning btn-sm" onClick={handleWithdraw} disabled={withdrawing}>
      {withdrawing ? i18n.withdrawing : i18n.withdraw}
    </button>
  );
}
