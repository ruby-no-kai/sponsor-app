import React from "react";
import type { ExpenseFile } from "./types";
import { DropZoneIndicator } from "./FileDropOverlay";
import { useI18n } from "./I18nContext";

type RightPaneProps = {
  file: ExpenseFile | null;
  filesUrl: string;
  isDragging: boolean;
  isDropTarget: boolean;
  linkedEnabled: boolean;
};

export function RightPane({
  file,
  filesUrl,
  isDragging,
  isDropTarget,
  linkedEnabled,
}: RightPaneProps) {
  const i18n = useI18n();

  if (!file) {
    return (
      <div
        data-drop-zone="linked"
        className="border-left d-flex align-items-center justify-content-center text-muted"
        style={{ flex: "5 0 0", minWidth: "300px", position: "relative" }}
      >
        {i18n.select_file}
        <DropZoneIndicator
          visible={isDragging}
          highlighted={isDropTarget}
          label=""
          enabled={linkedEnabled}
        />
      </div>
    );
  }

  const previewUrl = `${filesUrl}/${file.id}`;
  const isImage = file.content_type?.startsWith("image/");
  const isPdf = file.content_type === "application/pdf";

  return (
    <div
      data-drop-zone="linked"
      className="border-left d-flex flex-column"
      style={{ flex: "5 0 0", minWidth: "300px", position: "relative" }}
    >
      <div className="p-2 bg-light border-bottom">
        <strong className="small text-truncate d-block">
          {file.filename || `File #${file.id}`}
        </strong>
      </div>
      <div
        className="flex-grow-1 d-flex align-items-center justify-content-center p-2"
        style={{ overflow: "auto" }}
      >
        {isImage && (
          <img
            src={previewUrl}
            alt={file.filename}
            style={{ maxWidth: "100%", maxHeight: "100%" }}
          />
        )}
        {isPdf && (
          <iframe
            src={previewUrl}
            title={file.filename}
            style={{ width: "100%", height: "100%", border: "none" }}
          />
        )}
        {!isImage && !isPdf && (
          <div className="text-muted small">
            {i18n.no_preview}{" "}
            <a href={previewUrl} target="_blank" rel="noreferrer">
              {i18n.download}
            </a>
          </div>
        )}
      </div>
      <DropZoneIndicator
        visible={isDragging}
        highlighted={isDropTarget}
        label=""
        enabled={linkedEnabled}
      />
    </div>
  );
}
