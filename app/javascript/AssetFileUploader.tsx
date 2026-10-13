import { fromJson, type JsonValue } from "@bufbuild/protobuf";
import axios from "axios";

import Rails from "@rails/ujs";

import {
  AssetFileUploadSchema,
  type AssetFileUpload,
} from "./gen/rubykaigi/sponsor_app/asset_file_upload_pb";

export type UploadProgress = { loaded: number; total: number };

type Params = {
  file: File;
  sessionEndpoint: string;
  sessionEndpointMethod: string;
  onProgress?: (progress: UploadProgress) => any;
};

// Reads the upload session the server answers, ignoring fields a newer release adds.
export function parseAssetFileUpload(json: JsonValue): AssetFileUpload {
  const session = fromJson(AssetFileUploadSchema, json, {
    ignoreUnknownFields: true,
  });
  if (session.fileId === "0") {
    throw new Error("Upload session has no file_id");
  }
  return session;
}

export default class AssetFileUploader {
  public file: File;
  public sessionEndpoint: string;
  public sessionEndpointMethod: string;
  public fileId?: string;

  public onProgress?: (progress: { loaded: number; total: number }) => any;

  private session?: AssetFileUpload;

  constructor(params: Params) {
    this.file = params.file;
    this.sessionEndpoint = params.sessionEndpoint;
    this.sessionEndpointMethod = params.sessionEndpointMethod;
    this.onProgress = params.onProgress;
  }

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    // FIXME: Replace this with https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toBase64
    // https://github.com/microsoft/TypeScript/commit/3a68348fcbb5916228a722c433017cc5af75a0fe
    const bytes = new Uint8Array(buffer);
    let binary = "";
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }

  private async calculateSHA256(): Promise<string> {
    const buffer = await this.file.arrayBuffer();
    const hashBuffer = await crypto.subtle.digest("SHA-256", buffer);
    return this.arrayBufferToBase64(hashBuffer);
  }

  public async getSession() {
    if (this.session) return this.session;

    const sessionPayload = new FormData();
    sessionPayload.append("extension", this.file.name.split(".").pop() || "");
    sessionPayload.append("content_type", this.file.type);
    sessionPayload.append(Rails.csrfParam() || "", Rails.csrfToken() || "");
    const sessionResp = await fetch(this.sessionEndpoint, {
      method: this.sessionEndpointMethod,
      credentials: "include",
      body: sessionPayload,
    });
    if (sessionResp.ok) {
      const session = parseAssetFileUpload(await sessionResp.json());
      this.session = session;
      this.fileId = session.fileId;
      return session;
    } else {
      throw `Uploader getSession failed: status=${sessionResp.status}`;
    }
  }

  public async perform() {
    const session = await this.getSession();

    if (session.maxSize && BigInt(this.file.size) > session.maxSize) {
      throw new Error(
        `File size (${this.file.size} bytes) exceeds maximum allowed size (${session.maxSize} bytes)`,
      );
    }

    const checksum = await this.calculateSHA256();

    const formData = new FormData();

    Object.entries(session.fields).forEach(([key, value]) => {
      formData.append(key, value);
    });

    formData.append("x-amz-checksum-algorithm", "SHA256");
    formData.append("x-amz-checksum-sha256", checksum);
    if (!("Content-Type" in session.fields)) {
      formData.append("Content-Type", this.file.type);
    }
    formData.append("file", this.file);

    const response = await axios.post(session.url, formData, {
      onUploadProgress: (progressEvent) => {
        if (this.onProgress && progressEvent.total) {
          this.onProgress({
            loaded: progressEvent.loaded,
            total: progressEvent.total,
          });
        }
      },
    });

    const version_id = response.headers["x-amz-version-id"];
    const extension = this.file.name.split(".").pop() || "";

    await axios.put(
      session.reportTo,
      {
        extension,
        version_id,
      },
      {
        headers: {
          "x-csrf-token": Rails.csrfToken() || "",
        },
      },
    );
  }
}
