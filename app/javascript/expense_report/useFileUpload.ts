import { useState, useCallback, useRef } from "react";
import AssetFileUploader from "../AssetFileUploader";
import type { UploadDialogState, FileUploadEntry } from "./UploadDialog";
import { deleteFile, updateLineItem, createLineItem, fetchReport } from "./api";
import type { ExpenseReport } from "./types";
import Rails from "@rails/ujs";

type UseFileUploadOptions = {
  filesUrl: string;
  reportUrl: string;
  lineItemsUrl: string;
  csrfToken: string;
  onReportUpdate: (report: ExpenseReport) => void;
  onError: (message: string) => void;
  onSelectItem: (id: number) => void;
  onSelectFile: (id: number) => void;
};

export function useFileUpload({
  filesUrl,
  reportUrl,
  lineItemsUrl,
  csrfToken,
  onReportUpdate,
  onError,
  onSelectItem,
  onSelectFile,
}: UseFileUploadOptions) {
  const [dialogState, setDialogState] = useState<UploadDialogState>({ kind: "idle" });
  const opts = { csrfToken };

  const entriesRef = useRef<FileUploadEntry[]>([]);
  const fileSizesRef = useRef<number[]>([]);
  const completedBytesRef = useRef(0);
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

  // Create the ExpenseFile record (pending) with filename/content_type
  const createFileRecord = useCallback(
    async (file: File): Promise<{ id: number; initiateUrl: string }> => {
      const formData = new FormData();
      formData.append("extension", file.name.split(".").pop() || "");
      formData.append("filename", file.name);
      formData.append("content_type", file.type);
      formData.append(Rails.csrfParam() || "", Rails.csrfToken() || "");

      const resp = await fetch(filesUrl, {
        method: "POST",
        credentials: "include",
        body: formData,
      });
      if (!resp.ok) {
        throw new Error(`Failed to create file record: ${resp.status}`);
      }
      const session = await resp.json();
      const id = parseInt(session.id, 10);
      return { id, initiateUrl: `${filesUrl}/${id}/initiate_update` };
    },
    [filesUrl],
  );

  const performUploadAt = useCallback(
    async (index: number): Promise<number | null> => {
      const file = allFilesRef.current[index];
      setEntryStatus(index, "uploading");
      updateDialog();

      try {
        // Step 1: create pending record with filename/content_type
        const { id, initiateUrl } = await createFileRecord(file);
        currentFileIdRef.current = id;

        // Step 2: upload to S3 via AssetFileUploader
        // Use initiate_update as session endpoint — it returns presigned
        // URL for an existing record. The report_to PUT marks as uploaded.
        const uploader = new AssetFileUploader({
          file,
          sessionEndpoint: initiateUrl,
          sessionEndpointMethod: "POST",
          onProgress: (p) => updateDialog(p),
        });

        await uploader.perform();

        completedBytesRef.current += file.size;
        setEntryStatus(index, "done");
        updateDialog();
        return id;
      } catch (e) {
        const message = e instanceof Error ? e.message : "Upload failed";

        setEntryStatus(index, "error", message);
        updateDialog();

        return new Promise<number | null>((resolve) => {
          retryHandlerRef.current = async () => {
            setEntryStatus(index, "uploading", undefined);
            updateDialog();
            try {
              const id = await performUploadAt(index);
              resolve(id);
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
    [filesUrl, createFileRecord, opts, setEntryStatus, updateDialog],
  );

  const handleRetry = useCallback(() => {
    retryHandlerRef.current?.();
  }, []);

  const handleDiscard = useCallback(() => {
    discardHandlerRef.current?.();
  }, []);

  const startUpload = useCallback(
    async (files: File[], linkToItemId?: number | null, createNewItem?: boolean) => {
      linkToItemIdRef.current = linkToItemId ?? null;
      uploadedIdsRef.current = [];
      completedBytesRef.current = 0;
      allFilesRef.current = files;
      fileSizesRef.current = files.map((f) => f.size || 1);
      entriesRef.current = files.map((f) => ({ name: f.name, status: "waiting" as const }));
      updateDialog();

      for (let i = 0; i < files.length; i++) {
        const id = await performUploadAt(i);
        if (id !== null) {
          uploadedIdsRef.current.push(id);
        }
      }

      setDialogState({ kind: "done" });

      // Create a new line item if requested and no item was selected
      const itemId = linkToItemIdRef.current;
      if (!itemId && createNewItem && uploadedIdsRef.current.length > 0) {
        try {
          const result = await createLineItem(
            lineItemsUrl,
            {
              title: "New expense",
              amount: "0",
              tax_amount: "0",
              file_ids: uploadedIdsRef.current,
            },
            opts,
          );
          onReportUpdate(result);
          const newItem = result.line_items[result.line_items.length - 1];
          if (newItem) onSelectItem(newItem.id);
          return;
        } catch (e) {
          onError(e instanceof Error ? e.message : "Failed to create line item");
        }
      }

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
            onSelectItem(itemId);
            return;
          }
        } catch (e) {
          onError(e instanceof Error ? e.message : "Failed to link files");
        }
      }

      try {
        const refreshed = await fetchReport(reportUrl, opts);
        onReportUpdate(refreshed);
        if (uploadedIdsRef.current.length > 0) {
          onSelectFile(uploadedIdsRef.current[0]);
        }
      } catch (e) {
        onError(e instanceof Error ? e.message : "Failed to refresh");
      }
    },
    [
      performUploadAt,
      updateDialog,
      reportUrl,
      lineItemsUrl,
      opts,
      onReportUpdate,
      onError,
      onSelectItem,
      onSelectFile,
    ],
  );

  return { dialogState, startUpload, handleRetry, handleDiscard };
}
