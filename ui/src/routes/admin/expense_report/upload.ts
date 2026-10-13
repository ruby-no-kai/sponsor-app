import type { ExpenseFileUpload } from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";

// What ExpenseFileUploadInput.content_type takes.
export const ALLOWED_CONTENT_TYPES: readonly string[] = [
  "image/jpeg",
  "image/png",
  "image/gif",
  "image/webp",
  "application/pdf",
];

export function isAllowedFile(file: Pick<File, "type">): boolean {
  return ALLOWED_CONTENT_TYPES.includes(file.type);
}

// The extension of a file's name, such as "pdf", or empty for a name without one.
export function extensionOf(filename: string): string {
  const at = filename.lastIndexOf(".");
  return at <= 0 ? "" : filename.slice(at + 1);
}

export async function sha256Base64(blob: Blob): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", await blob.arrayBuffer()));
  return btoa(String.fromCharCode(...digest));
}

// The multipart form a presigned POST takes: its fields, the checksum the storage verifies, then
// the file, which the storage requires last.
export function storageFormData(upload: ExpenseFileUpload, file: File, checksum: string): FormData {
  const form = new FormData();
  for (const [name, value] of Object.entries(upload.fields)) form.append(name, value);
  form.append("x-amz-checksum-algorithm", "SHA256");
  form.append("x-amz-checksum-sha256", checksum);
  if (!("Content-Type" in upload.fields)) form.append("Content-Type", file.type);
  form.append("file", file);
  return form;
}

export type Progress = { loaded: number; total: number };

// Sends a form to the storage and returns the version it answered with, empty when it gave none.
export type StoragePost = (
  url: string,
  form: FormData,
  onProgress: (progress: Progress) => void,
) => Promise<string>;

// XMLHttpRequest, as fetch reports no upload progress. The storage's CORS rules expose
// x-amz-version-id.
export const postToStorage: StoragePost = (url, form, onProgress) =>
  new Promise((resolve, reject) => {
    const request = new XMLHttpRequest();
    request.open("POST", url);
    request.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) onProgress({ loaded: event.loaded, total: event.total });
    });
    request.addEventListener("load", () => {
      if (request.status >= 200 && request.status < 300) {
        resolve(request.getResponseHeader("x-amz-version-id") ?? "");
      } else {
        reject(new Error(`The storage refused the upload (HTTP ${request.status})`));
      }
    });
    request.addEventListener("error", () =>
      reject(new Error("The upload failed to reach the storage")),
    );
    request.send(form);
  });

// Sends a file with a presigned POST, returning the version the storage gave it.
export async function sendToStorage(
  upload: ExpenseFileUpload,
  file: File,
  post: StoragePost,
  onProgress: (progress: Progress) => void,
): Promise<string> {
  const maxSize = Number(upload.maxSize);
  if (file.size > maxSize) {
    throw new Error(`${file.name} is ${file.size} bytes, more than the ${maxSize} bytes allowed`);
  }
  return post(upload.url, storageFormData(upload, file, await sha256Base64(file)), onProgress);
}
