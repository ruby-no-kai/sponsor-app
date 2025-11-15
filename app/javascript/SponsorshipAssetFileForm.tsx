import * as React from "react";
import { useState, useRef, useImperativeHandle, forwardRef } from "react";

import SponsorshipAssetFileUploader, {
  UploadProgress,
} from "./SponsorshipAssetFileUploader";

interface UploadState {
  uploader?: SponsorshipAssetFileUploader;
  progress?: UploadProgress | null;
  error?: string | null;
}

export interface SponsorshipAssetFileFormAPI {
  startUpload: () => Promise<string | null>;
  ensureUpload: () => Promise<string | null>;
  needUpload: () => boolean;
  uploadRequired: () => boolean;
}

interface Props {
  existingFileId: string | null;
  needUpload: boolean;
  sessionEndpoint: string;
  sessionEndpointMethod: string;
}

const SponsorshipAssetFileForm = forwardRef<SponsorshipAssetFileFormAPI, Props>(
  (props, ref) => {
    const [needUpload, setNeedUpload] = useState(props.needUpload);
    const [uploadState, setUploadState] = useState<UploadState | undefined>(
      undefined,
    );
    const [file, setFile] = useState<File | null>(null);
    const [filename, setFilename] = useState<string | null>(null);
    const formRef = useRef<HTMLFormElement>(null);
    const uploadPromiseRef = useRef<Promise<string | null> | null>(null);
    const cachedResultRef = useRef<string | null | undefined>(undefined);

    const needUploadFn = () => needUpload;

    const uploadRequiredFn = () => props.needUpload;

    const startUpload = async (): Promise<string | null> => {
      if (!needUploadFn() && !uploadRequiredFn())
        return props.existingFileId || "";
      const form = formRef.current;
      if (!(form && form.reportValidity())) {
        console.log("Form is invalid, cannot start upload");
        return null;
      }
      if (!file) {
        console.log("No file selected, cannot start upload");
        return null;
      }

      const uploader = new SponsorshipAssetFileUploader({
        file,
        sessionEndpoint: props.sessionEndpoint,
        sessionEndpointMethod: props.sessionEndpointMethod,
      });
      setUploadState({ uploader });

      await uploader.perform();
      return uploader.fileId || null;
    };

    const ensureUpload = async (): Promise<string | null> => {
      if (cachedResultRef.current !== undefined) {
        return cachedResultRef.current;
      }

      if (uploadPromiseRef.current) {
        return uploadPromiseRef.current;
      }

      const promise = startUpload();
      uploadPromiseRef.current = promise;

      try {
        const result = await promise;
        if (result !== null) {
          cachedResultRef.current = result;
        }
        return result;
      } finally {
        uploadPromiseRef.current = null;
      }
    };

    useImperativeHandle(
      ref,
      () => ({
        startUpload,
        ensureUpload,
        needUpload: needUploadFn,
        uploadRequired: uploadRequiredFn,
      }),
      [file, needUpload, props.existingFileId],
    );

    const onReuploadClick = (e: React.MouseEvent<HTMLButtonElement>) => {
      setNeedUpload(true);
    };

    const onFileSelection = (e: React.ChangeEvent<HTMLInputElement>) => {
      if (!(e.target.files && e.target.files[0])) return;
      console.log("Selected file:", e.target.files[0]);
      setFile(e.target.files[0]);
      setFilename(e.target.files[0].name);
    };

    if (needUploadFn()) {
      return (
        <form action="#" ref={formRef}>
          <input
            type="file"
            onChange={onFileSelection}
            required={uploadRequiredFn()}
            accept="image/svg,image/svg+xml,application/pdf,application/zip,.ai,.eps"
          />
        </form>
      );
    } else {
      return (
        <button className="btn btn-info" onClick={onReuploadClick}>
          Re-upload
        </button>
      );
    }
  },
);

SponsorshipAssetFileForm.displayName = "SponsorshipAssetFileForm";

export default SponsorshipAssetFileForm;
