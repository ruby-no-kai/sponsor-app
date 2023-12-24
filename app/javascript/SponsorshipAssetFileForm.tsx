import S3 from "aws-sdk/clients/s3";
import * as React from "react";

import SponsorshipAssetFileUploader from "./SponsorshipAssetFileUploader";

interface UploadState {
  uploader?: SponsorshipAssetFileUploader;
  progress?: S3.ManagedUpload.Progress | null;
  error?: string | null;
}

interface Props {
  existingFileId: string | null;
  needUpload: boolean;
  sessionEndpoint: string;
  sessionEndpointMethod: string;
}

interface State {
  needUpload: boolean;
  uploadState?: UploadState;
  file: File | null;
  filename: string | null;
}

export default class SponsorshipAssetFileForm extends React.Component<
  Props,
  State
> {
  private formRef: React.RefObject<HTMLFormElement>;

  constructor(props: Props) {
    super(props);
    this.state = {
      needUpload: this.props.needUpload,
      uploadState: undefined,
      file: null,
      filename: null,
    };
    this.formRef = React.createRef();
  }

  public render() {
    if (this.needUpload()) {
      return (
        <form action="#" ref={this.formRef}>
          <input
            type="file"
            onChange={this.onFileSelection.bind(this)}
            required={this.uploadRequired()}
            accept="image/svg,application/pdf,application/zip,.ai,.eps"
          />
        </form>
      );
    } else {
      return (
        <button
          className="btn btn-info"
          onClick={this.onReuploadClick.bind(this)}
        >
          Re-upload
        </button>
      );
    }
  }

  private onReuploadClick(e: React.MouseEvent<HTMLButtonElement>) {
    this.setState({
      needUpload: true,
    });
  }

  private onFileSelection(e: React.ChangeEvent<HTMLInputElement>) {
    if (!(e.target.files && e.target.files[0])) return;
    this.setState({
      file: e.target.files[0],
      filename: e.target.files[0].name,
    });
  }

  public needUpload() {
    return this.state.needUpload;
  }

  public uploadRequired() {
    return this.props.needUpload;
  }

  public async startUpload(): Promise<string | null> {
    if (!this.needUpload() && !this.uploadRequired())
      return this.props.existingFileId || "";
    const form = this.formRef.current;
    if (!(form && form.reportValidity())) return null;
    if (!this.state.file) return null;

    const uploader = new SponsorshipAssetFileUploader({
      file: this.state.file,
      sessionEndpoint: this.props.sessionEndpoint,
      sessionEndpointMethod: this.props.sessionEndpointMethod,
    });
    this.setState({
      uploadState: { uploader: uploader },
    });

    await uploader.perform();
    return uploader.fileId || null;
  }
}
