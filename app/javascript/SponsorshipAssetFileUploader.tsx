import AWS from 'aws-sdk/global';
import S3 from 'aws-sdk/clients/s3';

import Rails from 'rails-ujs';

interface Params {
  file: File,
  sessionEndpoint: string,
  sessionEndpointMethod: string,
  onProgress?: (progress: S3.ManagedUpload.Progress) => any;
}

export interface SessionCredentials {
  access_key_id: string,
  secret_access_key: string,
  session_token?: string,
}

export interface SessionData {
  id: string,
  region: string,
  bucket: string,
  key: string,
  credentials: SessionCredentials,
}

export default class SponsorshipAssetFileUploader {
  public file: File;
  public sessionEndpoint: string;
  public sessionEndpointMethod: string;
  public fileId?: string;

  public onProgress?: (progress: S3.ManagedUpload.Progress) => any;

  private session?: SessionData;
  private uploader?: S3.ManagedUpload;
  private s3?: S3;
  private credentials?: AWS.Credentials;

  constructor(params: Params) {
    this.file = params.file;
    this.sessionEndpoint = params.sessionEndpoint;
    this.sessionEndpointMethod = params.sessionEndpointMethod;
    this.onProgress = params.onProgress;
  }

  public async getSession() {
    if (this.session) return this.session;

    const sessionPayload = new FormData();
    sessionPayload.append('extension', this.file.name.split('.').pop() || '');
    sessionPayload.append(Rails.csrfParam() || '', Rails.csrfToken() || '');
    const sessionResp = await fetch(this.sessionEndpoint, {method: this.sessionEndpointMethod, credentials: 'include', body: sessionPayload});
    if (sessionResp.ok) {
      const session: SessionData = await sessionResp.json();
      this.session = session;
      this.fileId = this.session.id;
      this.credentials = new AWS.Credentials({
        accessKeyId: session.credentials.access_key_id,
        secretAccessKey: session.credentials.secret_access_key,
        sessionToken: session.credentials.session_token,
      });
      return this.session;
    } else {
      throw `Uploader getSession failed: status=${sessionResp.status}`;
    }
  }

  public async getS3() {
    if (this.s3) return this.s3;
    const session = await this.getSession();
    this.s3 = new S3({
      useDualStack: true,
      region: session.region,
      credentials: this.credentials,
    });
    return this.s3;
  }

  public async getUploader() {
    if (this.uploader) return this.uploader;

    const session = await this.getSession();
    const s3 = await this.getS3();
    const uploader = new S3.ManagedUpload({
      service: s3,
      params: {
        Bucket: session.bucket,
        Key: session.key,
        ContentType: this.file.type,
        Body: this.file,
      },
    });
    if (this.onProgress) uploader.on('httpUploadProgress', this.onProgress);

    this.uploader = uploader;
    return this.uploader;
  }

  public async perform() {
    const {bucket, key} = await this.getSession();
    const uploader = await this.getUploader();
    const s3 = await this.getS3();

    await uploader.promise();
  }
}
