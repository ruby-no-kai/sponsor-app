import { useState, useCallback, useRef } from "react";
import AssetFileUploader from "../AssetFileUploader";
import type { UploadDialogState, FileUploadEntry } from "./UploadDialog";
import { deleteFile, updateLineItem, fetchReport } from "./api";
import type { ExpenseReport } from "./types";

type UseFileUploadOptions = {
  filesUrl: string;
  reportUrl: string;
  lineItemsUrl: string;
  csrfToken: string;
  onReportUpdate: (report: ExpenseReport) => void;
  onError: (message: string) => void;
};

export function useFileUpload({
  filesUrl,
  reportUrl,
  lineItemsUrl,
  csrfToken,
  onReportUpdate,
  onError,
}: UseFileUploadOptions) {
  const [dialogState, setDialogState] = useState<UploadDialogState>({ kind: "idle" });
  const opts = { csrfToken };

  // Mutable state for the upload batch
  const entriesRef = useRef<FileUploadEntry[]>([]);
  const fileSizesRef = useRef<number[]>([]);
  const completedBytesRef = useRef(0);
  const currentIndexRef = useRef(0);
  const currentFileIdRef = useRef<number | null>(null);
  const uploadedIdsRef = useRef<number[]>([]);
  const linkToItemIdRef = useRef<number | null>(null);
  const allFilesRef = useRef<File[]>([]);

  const retryHandlerRef = useRef<(() => void) | null>(null);
  const discardHandlerRef = useRef<(() => void) | null>(null);

  const totalBytes = () => fileSizesRef.current.reduce((a, b) => a + b, 0);

  const updateDialog = useCallback((currentProgress?: { loaded: number; total: number }) => {
    const overallLoaded =
      completedBytesRef.current + (currentProgress ? currentProgress.loaded : 0);
    const errorIndex = entriesRef.current.findIndex((e) => e.status === "error");

    setDialogState({
      kind: "active",
      files: [...entriesRef.current],
      overallLoaded,
      overallTotal: totalBytes(),
      errorIndex: errorIndex >= 0 ? errorIndex : null,
    });
  }, []);

  const setEntryStatus = useCallback(
    (index: number, status: FileUploadEntry["status"], error?: string) => {
      entriesRef.current = entriesRef.current.map((e, i) =>
        i === index ? { ...e, status, error } : e,
      );
    },
    [],
  );

  const reportBack = useCallback(
    async (fileId: string, file: File) => {
      const resp = await fetch(`${filesUrl}/${fileId}`, {
        method: "PUT",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
        },
        body: JSON.stringify({
          filename: file.name,
          content_type: file.type,
          extension: file.name.split(".").pop() || "",
          version_id: "",
        }),
      });
      if (!resp.ok) {
        throw new Error(`Failed to finalize upload: ${resp.status}`);
      }
    },
    [filesUrl, csrfToken],
  );

  const performUploadAt = useCallback(
    async (index: number): Promise<number | null> => {
      const file = allFilesRef.current[index];
      setEntryStatus(index, "uploading");
      updateDialog();

      const uploader = new AssetFileUploader({
        file,
        sessionEndpoint: filesUrl,
        sessionEndpointMethod: "POST",
        onProgress: (p) => updateDialog(p),
      });

      try {
        await uploader.perform();
        const fileId = parseInt(uploader.fileId!, 10);
        currentFileIdRef.current = fileId;

        await reportBack(uploader.fileId!, file);

        completedBytesRef.current += file.size;
        setEntryStatus(index, "done");
        updateDialog();
        return fileId;
      } catch (e) {
        const message = e instanceof Error ? e.message : "Upload failed";
        currentFileIdRef.current = uploader.fileId ? parseInt(uploader.fileId, 10) : null;

        setEntryStatus(index, "error", message);
        updateDialog();

        // Wait for user to retry or discard
        return new Promise<number | null>((resolve) => {
          retryHandlerRef.current = async () => {
            setEntryStatus(index, "uploading", undefined);
            updateDialog();
            try {
              if (uploader.fileId) {
                await uploader.perform();
                await reportBack(uploader.fileId, file);
                completedBytesRef.current += file.size;
                setEntryStatus(index, "done");
                updateDialog();
                resolve(parseInt(uploader.fileId, 10));
              } else {
                const id = await performUploadAt(index);
                resolve(id);
              }
            } catch (retryErr) {
              const retryMsg = retryErr instanceof Error ? retryErr.message : "Upload failed";
              setEntryStatus(index, "error", retryMsg);
              updateDialog();
            }
          };

          discardHandlerRef.current = async () => {
            if (currentFileIdRef.current) {
              try {
                await deleteFile(filesUrl, currentFileIdRef.current, opts);
              } catch {
                // Tolerate — garbage pending records acceptable
              }
            }
            setEntryStatus(index, "error", "Discarded");
            updateDialog();
            resolve(null);
          };
        });
      }
    },
    [filesUrl, reportBack, opts, setEntryStatus, updateDialog],
  );

  const handleRetry = useCallback(() => {
    retryHandlerRef.current?.();
  }, []);

  const handleDiscard = useCallback(() => {
    discardHandlerRef.current?.();
  }, []);

  const startUpload = useCallback(
    async (files: File[], linkToItemId?: number | null) => {
      linkToItemIdRef.current = linkToItemId ?? null;
      uploadedIdsRef.current = [];
      completedBytesRef.current = 0;
      allFilesRef.current = files;
      fileSizesRef.current = files.map((f) => f.size || 1);
      entriesRef.current = files.map((f) => ({ name: f.name, status: "waiting" as const }));
      updateDialog();

      for (let i = 0; i < files.length; i++) {
        currentIndexRef.current = i;
        const id = await performUploadAt(i);
        if (id !== null) {
          uploadedIdsRef.current.push(id);
        }
      }

      setDialogState({ kind: "done" });

      // Link uploaded files to item if requested
      const itemId = linkToItemIdRef.current;
      if (itemId && uploadedIdsRef.current.length > 0) {
        try {
          const refreshed = await fetchReport(reportUrl, opts);
          const item = refreshed.line_items.find((i) => i.id === itemId);
          if (item) {
            const allFileIds = [...item.file_ids, ...uploadedIdsRef.current];
            const result = await updateLineItem(
              lineItemsUrl,
              itemId,
              { file_ids: allFileIds },
              opts,
            );
            onReportUpdate(result);
            return;
          }
        } catch (e) {
          onError(e instanceof Error ? e.message : "Failed to link files");
        }
      }

      try {
        const refreshed = await fetchReport(reportUrl, opts);
        onReportUpdate(refreshed);
      } catch (e) {
        onError(e instanceof Error ? e.message : "Failed to refresh");
      }
    },
    [performUploadAt, updateDialog, reportUrl, lineItemsUrl, opts, onReportUpdate, onError],
  );

  return { dialogState, startUpload, handleRetry, handleDiscard };
}
