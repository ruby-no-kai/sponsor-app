import axios from "axios";

import Rails from "@rails/ujs";

export type UploadProgress = { loaded: number; total: number };

type Params = {
  file: File;
  sessionEndpoint: string;
  sessionEndpointMethod: string;
  onProgress?: (progress: UploadProgress) => any;
};

type SessionData = {
  id: string;
  url: string;
  fields: Record<string, string>;
};

export default class SponsorshipAssetFileUploader {
  public file: File;
  public sessionEndpoint: string;
  public sessionEndpointMethod: string;
  public fileId?: string;

  public onProgress?: (progress: { loaded: number; total: number }) => any;

  private session?: SessionData;

  constructor(params: Params) {
    this.file = params.file;
    this.sessionEndpoint = params.sessionEndpoint;
    this.sessionEndpointMethod = params.sessionEndpointMethod;
    this.onProgress = params.onProgress;
  }

  public async getSession() {
    if (this.session) return this.session;

    const sessionPayload = new FormData();
    sessionPayload.append("extension", this.file.name.split(".").pop() || "");
    sessionPayload.append(Rails.csrfParam() || "", Rails.csrfToken() || "");
    const sessionResp = await fetch(this.sessionEndpoint, {
      method: this.sessionEndpointMethod,
      credentials: "include",
      body: sessionPayload,
    });
    if (sessionResp.ok) {
      const session: SessionData = await sessionResp.json();
      this.session = session;
      this.fileId = this.session.id;
      return this.session;
    } else {
      throw `Uploader getSession failed: status=${sessionResp.status}`;
    }
  }

  public async perform() {
    const session = await this.getSession();

    const formData = new FormData();

    Object.entries(session.fields).forEach(([key, value]) => {
      formData.append(key, value);
    });

    formData.append("Content-Type", this.file.type);
    formData.append("file", this.file);

    await axios.post(session.url, formData, {
      onUploadProgress: (progressEvent) => {
        if (this.onProgress && progressEvent.total) {
          this.onProgress({
            loaded: progressEvent.loaded,
            total: progressEvent.total,
          });
        }
      },
    });
  }
}
