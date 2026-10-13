import { Button, Text } from "@cloudflare/kumo";
import { PlusIcon } from "@phosphor-icons/react";
import type { ReactNode } from "react";
import { useEditor } from "./EditorContext.ts";
import { PaneHeader, UploadHint } from "./EditorParts.tsx";
import { moveLineItem, newLineItemInput } from "./lineItemForm.ts";
import { fileName, unlinkedFiles } from "./reportView.ts";
import { SortableLineItemList } from "./SortableLineItemList.tsx";
import { useAction } from "./useAction.ts";

// The line items, then the files no line item attaches.
export function LeftPane({
  selectedItemId,
  selectedFileId,
  onSelectItem,
  onSelectFile,
  onUploadFiles,
  dropIndicator,
}: {
  selectedItemId: string | undefined;
  selectedFileId: string | undefined;
  onSelectItem: (id: string) => void;
  onSelectFile: (id: string) => void;
  onUploadFiles: (files: File[]) => void;
  dropIndicator: ReactNode;
}) {
  const {
    rpc,
    text,
    notify,
    report,
    rounding,
    readOnly,
    isMobile,
    applyReport,
    refreshReport,
    updateLineItem,
  } = useEditor();
  const createLineItem = useAction(rpc.createLineItem);

  async function handleAdd() {
    try {
      const response = await createLineItem.run(newLineItemInput(text("new_item_title")));
      applyReport(response.report);
      if (response.lineItem !== undefined) onSelectItem(response.lineItem.id);
    } catch (error) {
      notify(error);
    }
  }

  async function handleMove(movedId: string, overId: string) {
    const move = moveLineItem(report.lineItems, movedId, overId);
    if (move === undefined) return;
    // Shown at once, so the list does not jump back while the server answers.
    applyReport({ ...report, lineItems: move.items });
    try {
      await updateLineItem(movedId, () => ({ position: move.place }));
    } catch (error) {
      notify(error);
      await refreshReport();
    }
  }

  return (
    <div
      data-drop-zone="unlinked"
      className={`relative flex min-w-0 flex-col ${isMobile ? "" : "border-r border-kumo-line"}`}
    >
      <PaneHeader title={text("line_items")}>
        {!readOnly && (
          <Button
            variant="secondary"
            size="sm"
            icon={PlusIcon}
            loading={createLineItem.isRunning}
            onClick={() => void handleAdd()}
          >
            {text("add_item")}
          </Button>
        )}
      </PaneHeader>
      <div>
        <SortableLineItemList
          items={report.lineItems}
          decimal={rounding.decimal}
          selectedId={selectedItemId}
          onSelect={onSelectItem}
          onMove={(movedId, overId) => void handleMove(movedId, overId)}
          disabled={readOnly || isMobile}
        />
        {report.lineItems.length === 0 && (
          <div className="px-3 py-2">
            <Text variant="secondary" size="sm">
              {text("no_line_items")}
            </Text>
          </div>
        )}
      </div>

      <PaneHeader title={text("files")} />
      <ul>
        {unlinkedFiles(report).map((file) => (
          <li key={file.id.toString()}>
            <button
              type="button"
              onClick={() => onSelectFile(file.id)}
              aria-current={file.id === selectedFileId ? "true" : undefined}
              className={`w-full truncate border-b border-kumo-hairline px-3 py-2 text-left text-sm ${
                file.id === selectedFileId ? "bg-kumo-info-tint" : "hover:bg-kumo-tint"
              }`}
            >
              {fileName(file, text)}
            </button>
          </li>
        ))}
      </ul>
      {!readOnly && <UploadHint message="drop_to_add" onUploadFiles={onUploadFiles} />}
      {dropIndicator}
    </div>
  );
}
