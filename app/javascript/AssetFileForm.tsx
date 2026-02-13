import * as React from "react";
import { useState, useRef, useImperativeHandle, forwardRef } from "react";

import AssetFileUploader, {
  UploadProgress,
} from "./AssetFileUploader";

interface UploadState {
  uploader?: AssetFileUploader;
  progress?: UploadProgress | null;
  error?: string | null;
}

export interface AssetFileFormAPI {
  startUpload: () => Promise<string | null>;
  ensureUpload: () => Promise<string | null>;
  needUpload: () => boolean;
  uploadRequired: () => boolean;
}

type Props = {
  existingFileId: string | null;
  needUpload: boolean;
  sessionEndpoint: string;
  sessionEndpointMethod: string;
  accept: string;
  onFileChange?: (file: File | null) => void;
};

const AssetFileForm = forwardRef<AssetFileFormAPI, Props>(
  (props, ref) => {
    const [needUpload, setNeedUpload] = useState(props.needUpload);
    const [willReplace, setWillReplace] = useState(false);
    const [uploadState, setUploadState] = useState<UploadState | undefined>(
      undefined,
    );
    const [file, setFile] = useState<File | null>(null);
    const [filename, setFilename] = useState<string | null>(null);
    const formRef = useRef<HTMLFormElement>(null);
    const uploadPromiseRef = useRef<Promise<string | null> | null>(null);
    const cachedResultRef = useRef<string | null | undefined>(undefined);

    const startUpload = async (): Promise<string | null> => {
      if (!needUpload && !props.needUpload)
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

      const uploader = new AssetFileUploader({
        file,
        sessionEndpoint: props.sessionEndpoint,
        sessionEndpointMethod: props.sessionEndpointMethod,
        onProgress: (progress) => {
          setUploadState({ uploader, progress });
        },
      });
      setUploadState({ uploader, progress: null });

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
        needUpload: () => needUpload,
        uploadRequired: () => props.needUpload,
      }),
      [file, needUpload, props.existingFileId, props.needUpload],
    );

    const onReuploadClick = (e: React.MouseEvent<HTMLButtonElement>) => {
      setNeedUpload(true);
      setWillReplace(true);
    };

    const onCancelClick = (e: React.MouseEvent<HTMLButtonElement>) => {
      e.preventDefault();
      setNeedUpload(false);
      setWillReplace(false);
      setFile(null);
      setFilename(null);
      props.onFileChange?.(null);
    };

    const onFileSelection = (e: React.ChangeEvent<HTMLInputElement>) => {
      if (!(e.target.files && e.target.files[0])) return;
      const selectedFile = e.target.files[0];
      console.log("Selected file:", selectedFile);
      setFile(selectedFile);
      setFilename(selectedFile.name);
      props.onFileChange?.(selectedFile);
    };

    if (needUpload) {
      const progressPercentage =
        uploadState?.progress && uploadState.progress.total > 0
          ? Math.round(
              (uploadState.progress.loaded / uploadState.progress.total) * 100,
            )
          : null;

      return (
        <div>
          <form action="#" ref={formRef}>
            <input
              type="file"
              onChange={onFileSelection}
              required={props.needUpload}
              accept={props.accept}
              disabled={!!uploadState}
            />
          </form>
          {progressPercentage !== null && (
            <div className="mt-2">
              <div className="progress" style={{ height: "25px" }}>
                <div
                  className="progress-bar progress-bar-striped progress-bar-animated"
                  role="progressbar"
                  aria-valuenow={progressPercentage}
                  aria-valuemin={0}
                  aria-valuemax={100}
                  style={{ width: `${progressPercentage}%` }}
                >
                  {progressPercentage}%
                </div>
              </div>
            </div>
          )}
          {willReplace && !uploadState && (
            <button
              className="btn btn-secondary btn-sm mt-1"
              onClick={onCancelClick}
            >
              Cancel
            </button>
          )}
        </div>
      );
    } else {
      return (
        <button className="btn btn-info" onClick={onReuploadClick}>
          Replace
        </button>
      );
    }
  },
);

AssetFileForm.displayName = "AssetFileForm";

export default AssetFileForm;
