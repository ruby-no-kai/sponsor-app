import type { AssetUpload } from "../gen/rubykaigi/sponsor_app/asset_upload_pb.ts";

// What any presigned POST message, such as an AssetUpload or an ExpenseFileUpload, tells the browser.
export type PresignedPost = Pick<AssetUpload, "url" | "fields" | "maxSize">;

// The extension of a file's name, such as "pdf", or empty for a name without one.
export function extensionOf(filename: string): string {
  const at = filename.lastIndexOf(".");
  return at <= 0 ? "" : filename.slice(at + 1);
}

// A file's size for display, such as "420 B", "1.5 KB" or "12 MB".
export function formatFileSize(bytes: number): string {
  const units = ["B", "KB", "MB", "GB"];
  let size = bytes;
  let unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit += 1;
  }
  const text =
    unit === 0 || size >= 10 ? String(Math.round(size)) : size.toFixed(1).replace(/\.0$/, "");
  return `${text} ${units[unit]}`;
}

export async function sha256Base64(blob: Blob): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", await blob.arrayBuffer()));
  return btoa(String.fromCharCode(...digest));
}

// The multipart form a presigned POST takes: its fields, the checksum the storage verifies, then
// the file, which the storage requires last.
export function storageFormData(upload: PresignedPost, file: File, checksum: string): FormData {
  const form = new FormData();
  for (const [name, value] of Object.entries(upload.fields)) form.append(name, value);
  form.append("x-amz-checksum-algorithm", "SHA256");
  form.append("x-amz-checksum-sha256", checksum);
  if (!("Content-Type" in upload.fields)) form.append("Content-Type", file.type);
  form.append("file", file);
  return form;
}

export type Progress = { loaded: number; total: number };

// A file larger than the presigned POST takes, refused before sending it.
export class FileTooLargeError extends Error {
  readonly maxSize: bigint;

  constructor(file: File, maxSize: bigint) {
    super(`${file.name} is ${file.size} bytes, more than the ${maxSize} bytes allowed`);
    this.name = "FileTooLargeError";
    this.maxSize = maxSize;
  }
}

// The storage refused the upload or could not be reached. status is 0 for the latter.
export class StorageError extends Error {
  readonly status: number;

  constructor(status: number) {
    super(
      status === 0
        ? "The upload failed to reach the storage"
        : `The storage refused the upload (HTTP ${status})`,
    );
    this.name = "StorageError";
    this.status = status;
  }
}

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
        reject(new StorageError(request.status));
      }
    });
    request.addEventListener("error", () => reject(new StorageError(0)));
    request.send(form);
  });

// Sends a file with a presigned POST, returning the version the storage gave it.
export async function sendToStorage(
  upload: PresignedPost,
  file: File,
  post: StoragePost,
  onProgress: (progress: Progress) => void,
): Promise<string> {
  if (BigInt(file.size) > upload.maxSize) throw new FileTooLargeError(file, upload.maxSize);
  return post(upload.url, storageFormData(upload, file, await sha256Base64(file)), onProgress);
}

// The RPCs one upload runs through: one handing out the presigned POST, and one recording the
// file once the storage holds it.
export type UploadSteps = {
  start(): Promise<AssetUpload | undefined>;
  complete(fileId: bigint, versionId: string, extension: string): Promise<unknown>;
};

// Uploads a file from start to completion, returning the ID of the file record.
export async function uploadFile(
  file: File,
  steps: UploadSteps,
  {
    post = postToStorage,
    onProgress = () => {},
  }: { post?: StoragePost; onProgress?: (progress: Progress) => void } = {},
): Promise<bigint> {
  const upload = await steps.start();
  if (upload === undefined) throw new Error("The server handed out no upload");
  const versionId = await sendToStorage(upload, file, post, onProgress);
  await steps.complete(upload.fileId, versionId, extensionOf(file.name));
  return upload.fileId;
}

// Uploads a file at most once while it stays chosen, so a form refused after its file went up
// sends the same file record again. A failed upload is tried afresh.
export class UploadOnce {
  #file: File | undefined = undefined;
  #result: Promise<bigint> | undefined = undefined;

  ensure(file: File, upload: () => Promise<bigint>): Promise<bigint> {
    if (this.#file === file && this.#result !== undefined) return this.#result;
    const result = upload();
    this.#file = file;
    this.#result = result;
    result.catch(() => {
      if (this.#result === result) this.#result = undefined;
    });
    return result;
  }
}
