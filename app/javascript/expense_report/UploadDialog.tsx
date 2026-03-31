import React, { useRef, useEffect } from "react";
import { useI18n } from "./I18nContext";

export type FileUploadStatus = "waiting" | "uploading" | "done" | "error";

export type FileUploadEntry = {
  name: string;
  status: FileUploadStatus;
  error?: string;
};

export type UploadDialogState =
  | { kind: "idle" }
  | {
      kind: "active";
      files: FileUploadEntry[];
      overallLoaded: number;
      overallTotal: number;
      errorIndex: number | null;
    }
  | { kind: "done" };

type UploadDialogProps = {
  state: UploadDialogState;
  onRetry: () => void;
  onDiscard: () => void;
};

const STATUS_EMOJI: Record<FileUploadStatus, string> = {
  waiting: "⏳",
  uploading: "🔄",
  done: "✅",
  error: "❌",
};

export function UploadDialog({ state, onRetry, onDiscard }: UploadDialogProps) {
  const i18n = useI18n();
  const dialogRef = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;

    if (state.kind === "idle" || state.kind === "done") {
      dialog.close();
    } else if (!dialog.open) {
      dialog.showModal();
    }
  }, [state.kind]);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;

    const handleCancel = (e: Event) => {
      if (state.kind === "active" && state.errorIndex === null) {
        e.preventDefault();
      }
    };
    dialog.addEventListener("cancel", handleCancel);
    return () => dialog.removeEventListener("cancel", handleCancel);
  }, [state]);

  if (state.kind !== "active") {
    return <dialog ref={dialogRef} />;
  }

  const { files, overallLoaded, overallTotal, errorIndex } = state;
  const progressPercent = overallTotal > 0 ? Math.round((overallLoaded / overallTotal) * 100) : 0;
  const hasError = errorIndex !== null;

  return (
    <dialog
      ref={dialogRef}
      style={{
        border: "1px solid #dee2e6",
        borderRadius: "8px",
        padding: "1.5rem",
        minWidth: "400px",
        maxWidth: "500px",
      }}
    >
      <h5>{hasError ? i18n.upload_failed : i18n.uploading}</h5>

      <div className="progress mb-3" style={{ height: "20px" }}>
        <div
          className={`progress-bar ${hasError ? "bg-danger" : "progress-bar-striped progress-bar-animated"}`}
          role="progressbar"
          style={{ width: `${progressPercent}%` }}
        >
          {progressPercent}%
        </div>
      </div>

      <ul className="list-unstyled mb-3" style={{ maxHeight: "200px", overflow: "auto" }}>
        {files.map((f, i) => (
          <li key={i} className="small py-1">
            <span className="mr-1">{STATUS_EMOJI[f.status]}</span>
            <span className={f.status === "error" ? "text-danger" : ""}>{f.name}</span>
            {f.error && <span className="text-danger ml-1">&mdash; {f.error}</span>}
          </li>
        ))}
      </ul>

      {hasError && (
        <div className="d-flex justify-content-end" style={{ gap: "0.5rem" }}>
          <button className="btn btn-outline-danger btn-sm" onClick={onDiscard}>
            {i18n.discard}
          </button>
          <button className="btn btn-primary btn-sm" onClick={onRetry}>
            {i18n.retry}
          </button>
        </div>
      )}
    </dialog>
  );
}
