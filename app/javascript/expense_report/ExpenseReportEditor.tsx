import React, { useState, useEffect, useCallback } from "react";
import type { EditorProps, ExpenseReport, ExpenseFile, CalculateResponse } from "./types";
import { fetchReport, fetchCalculate } from "./api";
import { LeftPane } from "./LeftPane";
import { CenterPane } from "./CenterPane";
import { RightPane } from "./RightPane";
import { AdminReviewForm } from "./AdminReviewForm";
import { FileDropOverlay } from "./FileDropOverlay";
import { useFileUpload } from "./useFileUpload";
import { UploadDialog } from "./UploadDialog";
import { updateLineItem } from "./api";

export function ExpenseReportEditor(props: EditorProps) {
  const [report, setReport] = useState<ExpenseReport | null>(null);
  const [calcData, setCalcData] = useState<CalculateResponse | null>(null);
  const [selectedItemId, setSelectedItemId] = useState<number | null>(null);
  const [previewFileId, setPreviewFileId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const opts = { csrfToken: props.csrfToken };

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
      setError(e instanceof Error ? e.message : "Failed to load report");
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

  // File upload with modal dialog
  const { dialogState, startUpload, handleRetry, handleDiscard } = useFileUpload({
    filesUrl: props.filesUrl,
    reportUrl: props.reportUrl,
    lineItemsUrl: props.lineItemsUrl,
    csrfToken: props.csrfToken,
    onReportUpdate: handleReportUpdate,
    onError: setError,
  });

  const handleDropUnlinked = useCallback((files: File[]) => startUpload(files), [startUpload]);

  const handleDropLinked = useCallback(
    (files: File[]) => startUpload(files, selectedItemId),
    [startUpload, selectedItemId],
  );

  const selectedItem = report?.line_items.find((i) => i.id === selectedItemId);
  const previewFile = report?.files.find((f) => f.id === previewFileId);

  if (loading) {
    return (
      <div className="text-center py-5">
        <p>Loading expense report...</p>
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

      <div className="d-flex mb-2 justify-content-between align-items-center">
        <div>
          <StatusBadge status={report.status} />
          {calcData && (
            <span className="ml-3 text-muted">
              Total: {formatAmount(report.total_amount)} + tax{" "}
              {formatAmount(report.total_tax_amount)} / Fee: {formatAmount(calcData.total_fee)}
            </span>
          )}
        </div>
        <div>
          {!isReadOnly &&
            props.role === "sponsor" &&
            report.status === "draft" &&
            props.submissionUrl && (
              <SubmitButton
                submissionUrl={props.submissionUrl}
                opts={opts}
                onUpdate={handleReportUpdate}
                onError={setError}
              />
            )}
          {!isReadOnly &&
            props.role === "sponsor" &&
            report.status === "submitted" &&
            props.submissionUrl && (
              <WithdrawButton
                submissionUrl={props.submissionUrl}
                opts={opts}
                onUpdate={handleReportUpdate}
                onError={setError}
              />
            )}
        </div>
      </div>

      {report.status === "rejected" &&
        props.role === "sponsor" &&
        report.latest_review?.comment && (
          <div className="alert alert-danger mb-2">
            <strong>Review feedback:</strong> {report.latest_review.comment}
          </div>
        )}

      <FileDropOverlay
        selectedItem={selectedItem || null}
        disabled={isReadOnly}
        onDropUnlinked={handleDropUnlinked}
        onDropLinked={handleDropLinked}
      >
        <div className="d-flex border rounded" style={{ height: "80vh", overflow: "hidden" }}>
          <LeftPane
            report={report}
            selectedItemId={selectedItemId}
            onSelectItem={setSelectedItemId}
            onSelectFile={setPreviewFileId}
            isReadOnly={isReadOnly}
            lineItemsUrl={props.lineItemsUrl}
            opts={opts}
            onUpdate={handleReportUpdate}
            onError={setError}
            onUploadFiles={handleDropUnlinked}
          />
          <CenterPane
            item={selectedItem || null}
            report={report}
            calcData={calcData}
            isReadOnly={isReadOnly}
            lineItemsUrl={props.lineItemsUrl}
            filesUrl={props.filesUrl}
            opts={opts}
            onUpdate={handleReportUpdate}
            onError={setError}
            onPreviewFile={setPreviewFileId}
          />
          <RightPane file={previewFile || null} filesUrl={props.filesUrl} />
        </div>
      </FileDropOverlay>

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

function StatusBadge({ status }: { status: ExpenseReport["status"] }) {
  const badges: Record<string, string> = {
    draft: "badge-secondary",
    submitted: "badge-info",
    approved: "badge-success",
    rejected: "badge-danger",
  };
  return <span className={`badge ${badges[status] || "badge-light"}`}>{status}</span>;
}

function formatAmount(amount: string): string {
  const num = parseFloat(amount);
  return isNaN(num) ? amount : num.toLocaleString();
}

function SubmitButton({
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
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async () => {
    if (!confirm("Submit this expense report for review?")) return;
    setSubmitting(true);
    try {
      const { submitReport } = await import("./api");
      const result = await submitReport(submissionUrl, opts);
      onUpdate(result);
    } catch (e) {
      onError(e instanceof Error ? e.message : "Failed to submit");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <button className="btn btn-primary btn-sm" onClick={handleSubmit} disabled={submitting}>
      {submitting ? "Submitting..." : "Submit for Review"}
    </button>
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
  const [withdrawing, setWithdrawing] = useState(false);

  const handleWithdraw = async () => {
    if (!confirm("Withdraw this submission? You can re-submit later.")) return;
    setWithdrawing(true);
    try {
      const { withdrawSubmission } = await import("./api");
      const result = await withdrawSubmission(submissionUrl, opts);
      onUpdate(result);
    } catch (e) {
      onError(e instanceof Error ? e.message : "Failed to withdraw");
    } finally {
      setWithdrawing(false);
    }
  };

  return (
    <button className="btn btn-warning btn-sm" onClick={handleWithdraw} disabled={withdrawing}>
      {withdrawing ? "Withdrawing..." : "Withdraw Submission"}
    </button>
  );
}
