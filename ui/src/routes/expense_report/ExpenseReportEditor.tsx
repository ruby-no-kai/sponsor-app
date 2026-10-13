import { toJsonString } from "@bufbuild/protobuf";
import { Badge, Banner, Button, Text } from "@cloudflare/kumo";
import { ArrowLeftIcon, ChatTextIcon } from "@phosphor-icons/react";
import { useEffect, useRef, useState } from "react";
import type { ReactNode } from "react";
import { useLocation, useNavigate } from "react-router";
import {
  ExpenseLineItemSchema,
  ExpenseReportReview_Action,
} from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type {
  ExpenseReport,
  ExpenseReportCalculation,
} from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { labelOf } from "../admin/sponsorshipView.ts";
import { formatAmountAt, subtractAmounts } from "./amounts.ts";
import { EditorProvider } from "./EditorContext.ts";
import type { Editor } from "./EditorContext.ts";
import type { ExpenseRpc } from "./expenseRpc.ts";
import { FileDropOverlay, DropZoneIndicator } from "./FileDropOverlay.tsx";
import { FileView } from "./FileView.tsx";
import { LeftPane } from "./LeftPane.tsx";
import { lineItemInputOf } from "./lineItemForm.ts";
import { LineItemForm } from "./LineItemForm.tsx";
import {
  EXPENSE_REPORT_STATUS_LABELS,
  hashOf,
  isReadOnly,
  selectionFromHash,
  unlinkedFiles,
} from "./reportView.ts";
import type { Role, Selection } from "./reportView.ts";
import { RightPane } from "./RightPane.tsx";
import type { EditorText } from "./text.ts";
import { UploadDialog } from "./UploadDialog.tsx";
import { useFileUpload } from "./useFileUpload.ts";
import type { UploadTarget } from "./useFileUpload.ts";
import { useIsMobile } from "./useIsMobile.ts";

// What a role gives the editor: the RPCs it speaks, the words it says them in, and what shows
// around the panes.
export type ExpenseReportEditorProps = {
  role: Role;
  rpc: ExpenseRpc;
  text: EditorText;
  // Reports a failed action, in the language of text.
  notify: (error: unknown) => void;
  report: ExpenseReport;
  calculation: ExpenseReportCalculation;
  // Shows a report as an RPC answered it.
  onReport: (report: ExpenseReport) => void;
  // Reads the report again, after an RPC that answers none.
  onRefresh: () => Promise<void>;
  // The page redirecting to a file in the storage, for previews and downloads.
  fileUrl: (fileId: string) => string;
  // Above the figures.
  header: ReactNode;
  // In the bar kept at the bottom of the window, beside the status.
  actions?: ReactNode;
};

export function ExpenseReportEditor({
  role,
  rpc,
  text,
  notify,
  report,
  calculation,
  onReport,
  onRefresh,
  fileUrl,
  header,
  actions,
}: ExpenseReportEditorProps) {
  const isMobile = useIsMobile();
  const location = useLocation();
  const navigate = useNavigate();
  const selection = selectionFromHash(location.hash);
  const selectedItem =
    selection?.kind === "item"
      ? report.lineItems.find((item) => item.id === selection.id)
      : undefined;
  const selectedFile =
    selection?.kind === "file" ? report.files.find((file) => file.id === selection.id) : undefined;
  const [previewFileId, setPreviewFileId] = useState<string | undefined>(() =>
    selection?.kind === "file" ? selection.id : selectedItem?.fileIds[0],
  );
  const [mobileView, setMobileView] = useState<"list" | "detail">(
    selection === undefined ? "list" : "detail",
  );
  const dirtyRef = useRef(false);
  const readOnly = isReadOnly(report, role);

  function select(next: Selection) {
    void navigate(
      { pathname: location.pathname, search: location.search, hash: hashOf(next) },
      { replace: true, preventScrollReset: true },
    );
  }

  // Selecting another pane drops what the line item form holds, so a person is asked first.
  function confirmLeaving(): boolean {
    return !dirtyRef.current || window.confirm(text("confirm_discard"));
  }

  function showItem(id: string) {
    select({ kind: "item", id });
    setPreviewFileId(report.lineItems.find((item) => item.id === id)?.fileIds[0]);
    if (isMobile) setMobileView("detail");
  }

  function showFile(id: string) {
    select({ kind: "file", id });
    setPreviewFileId(id);
    if (isMobile) setMobileView("detail");
  }

  function clearSelection() {
    select(undefined);
    setPreviewFileId(undefined);
  }

  // The panes of a wide window are never left empty while the report has something to show.
  const hasSelection = selectedItem !== undefined || selectedFile !== undefined;
  const firstItem = report.lineItems[0];
  const firstFile = unlinkedFiles(report)[0];
  useEffect(() => {
    if (isMobile || hasSelection) return;
    if (firstItem !== undefined) {
      select({ kind: "item", id: firstItem.id });
      setPreviewFileId(firstItem.fileIds[0]);
    } else if (firstFile !== undefined) {
      select({ kind: "file", id: firstFile.id });
      setPreviewFileId(firstFile.id);
    }
  }, [isMobile, hasSelection, firstItem?.id, firstFile?.id]);

  function applyReport(next: ExpenseReport | undefined) {
    if (next !== undefined) onReport(next);
  }

  const editor: Editor = {
    role,
    rpc,
    text,
    notify,
    report,
    rounding: calculation,
    readOnly,
    isMobile,
    applyReport,
    refreshReport: onRefresh,
    async updateLineItem(lineItemId, change) {
      const fresh = await rpc.readReport();
      const item = fresh?.lineItems.find((candidate) => candidate.id === lineItemId);
      if (item === undefined) {
        applyReport(fresh);
        return false;
      }
      const response = await rpc.updateLineItem(lineItemId, {
        ...lineItemInputOf(item),
        ...change(item),
      });
      applyReport(response.report);
      return true;
    },
    fileUrl,
  };

  const upload = useFileUpload({
    editor,
    select: (next) => {
      if (next?.kind === "item") showItem(next.id);
      else if (next?.kind === "file") showFile(next.id);
    },
  });
  const linkedTarget: UploadTarget =
    selectedItem === undefined ? { kind: "new-item" } : { kind: "item", id: selectedItem.id };
  const uploadLinked = (files: File[]) => upload.start(files, linkedTarget);
  const uploadUnlinked = (files: File[]) => upload.start(files, { kind: "files" });

  const previewFile = report.files.find((file) => file.id === previewFileId);
  const review = report.latestReview;
  const statusTone = labelOf(EXPENSE_REPORT_STATUS_LABELS, report.status).tone;
  const remaining = subtractAmounts(calculation.totalFee, report.totalAmount);

  let center: ReactNode;
  if (selectedItem !== undefined) {
    center = (
      <LineItemForm
        key={toJsonString(ExpenseLineItemSchema, { ...selectedItem, position: 0 })}
        item={selectedItem}
        dirtyRef={dirtyRef}
        onSelectItem={showItem}
        onDeleted={clearSelection}
        onPreviewFile={setPreviewFileId}
        onUploadLinked={uploadLinked}
      />
    );
  } else if (selectedFile !== undefined && !readOnly) {
    center = <FileView file={selectedFile} onSelectItem={showItem} onDeleted={clearSelection} />;
  } else {
    center = (
      <div className="flex flex-1 items-center justify-center px-4 py-3">
        <Text variant="secondary">{text("select_line_item")}</Text>
      </div>
    );
  }

  const negative = remaining?.startsWith("-") ?? false;
  const remainingFigure =
    remaining === undefined ? undefined : formatAmountAt(remaining, calculation.decimal);

  return (
    <EditorProvider value={editor}>
      <div className="flex flex-col gap-4">
        {header}

        <div className="flex flex-wrap items-center gap-x-5 gap-y-1 text-sm">
          <Badge variant={statusTone}>{text.status(report.status)}</Badge>
          <Figure
            label={text("figure_fee")}
            value={formatAmountAt(calculation.totalFee, calculation.decimal)}
          />
          <Figure
            label={text("figure_expense")}
            value={formatAmountAt(report.totalAmount, calculation.decimal)}
          />
          <Figure
            label={text("figure_tax")}
            value={formatAmountAt(report.totalTaxAmount, calculation.decimal)}
          />
          {remainingFigure !== undefined && (
            <Figure
              label={text("figure_remaining")}
              value={remainingFigure}
              className={negative ? "text-kumo-danger" : ""}
            />
          )}
        </div>

        {review?.action === ExpenseReportReview_Action.REJECT && review.comment !== undefined && (
          <Banner
            variant="error"
            icon={<ChatTextIcon />}
            title={text("review_feedback")}
            description={<span className="whitespace-pre-wrap">{review.comment}</span>}
          />
        )}

        <FileDropOverlay
          disabled={readOnly}
          onDropUnlinked={uploadUnlinked}
          onDropLinked={uploadLinked}
          zoneOverride={isMobile ? (mobileView === "list" ? "unlinked" : "linked") : undefined}
        >
          {({ isDragging, hoverZone }) => (
            <div
              className={`overflow-clip rounded-lg border border-kumo-line bg-kumo-base ${
                isMobile ? "flex flex-col" : "grid grid-cols-[16rem_minmax(0,4fr)_minmax(0,5fr)]"
              }`}
            >
              {(!isMobile || mobileView === "list") && (
                <LeftPane
                  selectedItemId={selectedItem?.id}
                  selectedFileId={selection?.kind === "file" ? selection.id : undefined}
                  onSelectItem={(id) => {
                    if (confirmLeaving()) showItem(id);
                  }}
                  onSelectFile={(id) => {
                    if (confirmLeaving()) showFile(id);
                  }}
                  onUploadFiles={uploadUnlinked}
                  dropIndicator={
                    <DropZoneIndicator
                      visible={isDragging}
                      highlighted={hoverZone === "unlinked"}
                      label={text("drop_unlinked")}
                    />
                  }
                />
              )}
              {(!isMobile || mobileView === "detail") && (
                <>
                  {isMobile && (
                    <div className="border-b border-kumo-line px-2 py-1.5">
                      <Button
                        variant="secondary"
                        size="sm"
                        icon={ArrowLeftIcon}
                        onClick={() => {
                          if (!confirmLeaving()) return;
                          setMobileView("list");
                          clearSelection();
                        }}
                      >
                        {text("back")}
                      </Button>
                    </div>
                  )}
                  <div data-drop-zone="linked" className="relative flex min-w-0 flex-col">
                    {center}
                    <DropZoneIndicator
                      visible={isDragging}
                      highlighted={hoverZone === "linked"}
                      label={
                        selectedItem === undefined
                          ? text("drop_create_item")
                          : text("drop_link_to", { title: selectedItem.title })
                      }
                    />
                  </div>
                </>
              )}
              {!isMobile && (
                <RightPane
                  file={previewFile}
                  dropIndicator={
                    <DropZoneIndicator
                      visible={isDragging}
                      highlighted={hoverZone === "linked"}
                      label=""
                    />
                  }
                />
              )}
            </div>
          )}
        </FileDropOverlay>

        <div className="sticky bottom-0 z-20 flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-kumo-line bg-kumo-base py-3 text-sm">
          <Badge variant={statusTone}>{text.status(report.status)}</Badge>
          {remainingFigure !== undefined && (
            <Figure
              label={text("figure_remaining")}
              value={remainingFigure}
              className={negative ? "text-kumo-danger" : ""}
            />
          )}
          {actions !== undefined && (
            <div className="flex min-w-0 items-center gap-2 max-md:basis-full md:ml-auto md:flex-1 md:justify-end">
              {actions}
            </div>
          )}
        </div>

        <UploadDialog state={upload.state} onRetry={upload.retry} onDiscard={upload.discard} />
      </div>
    </EditorProvider>
  );
}

// A figure in running text, so its mono figures are a little smaller than the words around them.
function Figure({
  label,
  value,
  className = "",
}: {
  label: string;
  value: string;
  className?: string;
}) {
  return (
    <span className="whitespace-nowrap">
      <span className="text-kumo-subtle">{label}</span>{" "}
      <span className={`font-mono text-[0.9em] font-medium ${className}`}>{value}</span>
    </span>
  );
}
