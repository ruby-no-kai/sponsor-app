import { useState, useCallback } from "react";
import AssetFileUploader from "../AssetFileUploader";
import type { ExpenseFile } from "./types";

type UseFileUploadOptions = {
  filesUrl: string;
  csrfToken: string;
  onFileUploaded: (file: ExpenseFile) => void;
  onError: (message: string) => void;
};

export function useFileUpload({
  filesUrl,
  csrfToken,
  onFileUploaded,
  onError,
}: UseFileUploadOptions) {
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState<{
    loaded: number;
    total: number;
  } | null>(null);

  const uploadFile = useCallback(
    async (file: File) => {
      setUploading(true);
      setProgress(null);
      try {
        const uploader = new AssetFileUploader({
          file,
          sessionEndpoint: filesUrl,
          sessionEndpointMethod: "POST",
          onProgress: setProgress,
        });

        await uploader.perform();

        // Report filename and content_type to the update endpoint
        const updateResp = await fetch(`${filesUrl}/${uploader.fileId}`, {
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

        if (!updateResp.ok) {
          throw new Error(`Failed to update file metadata: ${updateResp.status}`);
        }

        // Fetch the file info back from the report
        const fileResp = await fetch(`${filesUrl}/${uploader.fileId}`, {
          credentials: "include",
          headers: { Accept: "application/json" },
          redirect: "manual",
        });

        // The show action redirects to S3, so we construct the file object
        const uploadedFile: ExpenseFile = {
          id: parseInt(uploader.fileId!, 10),
          filename: file.name,
          content_type: file.type,
          created_at: new Date().toISOString(),
        };

        onFileUploaded(uploadedFile);
      } catch (e) {
        onError(e instanceof Error ? e.message : "Upload failed");
      } finally {
        setUploading(false);
        setProgress(null);
      }
    },
    [filesUrl, csrfToken, onFileUploaded, onError],
  );

  const uploadFiles = useCallback(
    async (files: File[]) => {
      for (const file of files) {
        await uploadFile(file);
      }
    },
    [uploadFile],
  );

  return { uploading, progress, uploadFile, uploadFiles };
}
