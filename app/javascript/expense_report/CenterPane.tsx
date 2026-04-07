import type { RefObject } from "react";
import type { ExpenseLineItem, ExpenseReport, CalculateResponse } from "./types";
import { DropZoneIndicator } from "./FileDropOverlay";
import { useI18n, t } from "./I18nContext";
import { LineItemForm } from "./LineItemForm";
import { FileView } from "./FileView";

type CenterPaneProps = {
  item: ExpenseLineItem | null;
  selectedFile: ExpenseReport["files"][number] | null;
  report: ExpenseReport;
  calcData: CalculateResponse | null;
  isReadOnly: boolean;
  lineItemsUrl: string;
  filesUrl: string;
  onUpdate: (r: ExpenseReport) => void;
  onError: (e: string) => void;
  onPreviewFile: (id: number | null) => void;
  onSelectItem: (id: number) => void;
  onRefresh: () => void;
  isDirtyRef: RefObject<boolean>;
  onUploadLinked: (files: File[]) => void;
  isDragging: boolean;
  isDropTarget: boolean;
  linkedEnabled: boolean;
  selectedItemTitle: string | null;
  isMobile: boolean;
};

export function CenterPane({
  item,
  selectedFile,
  report,
  calcData,
  isReadOnly,
  lineItemsUrl,
  filesUrl,
  onUpdate,
  onError,
  onPreviewFile,
  onSelectItem,
  onRefresh,
  isDirtyRef,
  onUploadLinked,
  isDragging,
  isDropTarget,
  linkedEnabled,
  selectedItemTitle,
  isMobile,
}: CenterPaneProps) {
  const i18n = useI18n();

  const dropLabel = selectedItemTitle
    ? t(i18n.drop_link_to, { title: selectedItemTitle })
    : i18n.drop_create_item;

  if (item) {
    return (
      <LineItemForm
        item={item}
        report={report}
        calcData={calcData}
        isReadOnly={isReadOnly}
        lineItemsUrl={lineItemsUrl}
        filesUrl={filesUrl}
        onUpdate={onUpdate}
        onError={onError}
        onPreviewFile={onPreviewFile}
        onSelectItem={onSelectItem}
        isDirtyRef={isDirtyRef}
        onUploadLinked={onUploadLinked}
        isDragging={isDragging}
        isDropTarget={isDropTarget}
        linkedEnabled={linkedEnabled}
        dropLabel={dropLabel}
        isMobile={isMobile}
      />
    );
  }

  return (
    <div
      data-drop-zone="linked"
      className="d-flex flex-column align-items-center justify-content-center text-muted"
      style={{
        flex: isMobile ? "1 1 auto" : "4 0 0",
        minWidth: isMobile ? undefined : "250px",
        overflow: "auto",
        position: "relative",
      }}
    >
      {selectedFile && !isReadOnly ? (
        <FileView
          file={selectedFile}
          report={report}
          filesUrl={filesUrl}
          lineItemsUrl={lineItemsUrl}
          onUpdate={onUpdate}
          onError={onError}
          onPreviewFile={onPreviewFile}
          onSelectItem={onSelectItem}
          onRefresh={onRefresh}
          isMobile={isMobile}
        />
      ) : (
        i18n.select_line_item
      )}
      <DropZoneIndicator
        visible={isDragging}
        highlighted={isDropTarget}
        label={dropLabel}
        enabled={linkedEnabled}
      />
    </div>
  );
}
