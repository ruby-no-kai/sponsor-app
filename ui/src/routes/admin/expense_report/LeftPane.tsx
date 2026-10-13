import { Button, Text } from "@cloudflare/kumo";
import { PlusIcon } from "@phosphor-icons/react";
import { AdminService } from "../../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { useRpcMutation } from "../../../lib/rpc.ts";
import { notifyError } from "../../../lib/toast.ts";
import { useEditor } from "./EditorContext.ts";
import { PaneHeader } from "./EditorParts.tsx";
import { moveLineItem, newLineItemInput } from "./lineItemForm.ts";
import { fileName, unlinkedFiles } from "./reportView.ts";
import { SortableLineItemList } from "./SortableLineItemList.tsx";

// The line items, then the files no line item attaches.
export function LeftPane({
  selectedItemId,
  selectedFileId,
  onSelectItem,
  onSelectFile,
}: {
  selectedItemId: string | undefined;
  selectedFileId: string | undefined;
  onSelectItem: (id: string) => void;
  onSelectFile: (id: string) => void;
}) {
  const {
    target,
    report,
    rounding,
    readOnly,
    isMobile,
    applyReport,
    refreshReport,
    updateLineItem,
  } = useEditor();
  const createLineItem = useRpcMutation(AdminService.method.createExpenseLineItem);

  async function handleAdd() {
    try {
      const response = await createLineItem.trigger({
        ...target,
        input: newLineItemInput("New expense"),
      });
      applyReport(response.report);
      if (response.lineItem !== undefined) onSelectItem(response.lineItem.id);
    } catch (error) {
      notifyError(error);
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
      notifyError(error);
      await refreshReport();
    }
  }

  return (
    <div
      className={`flex min-h-0 flex-col overflow-auto ${isMobile ? "flex-1" : "w-64 shrink-0 border-r border-kumo-line"}`}
    >
      <PaneHeader title="Line items">
        {!readOnly && (
          <Button
            variant="secondary"
            size="sm"
            shape="square"
            icon={PlusIcon}
            title="Add line item"
            aria-label="Add line item"
            loading={createLineItem.isMutating}
            onClick={() => void handleAdd()}
          />
        )}
      </PaneHeader>
      <div className="min-h-20 flex-1 overflow-auto">
        <SortableLineItemList
          items={report.lineItems}
          decimal={rounding.decimal}
          selectedId={selectedItemId}
          onSelect={onSelectItem}
          onMove={(movedId, overId) => void handleMove(movedId, overId)}
          disabled={readOnly || isMobile}
        />
        {report.lineItems.length === 0 && (
          <div className="p-3">
            <Text variant="secondary" size="sm">
              No line items yet
            </Text>
          </div>
        )}
      </div>

      <PaneHeader title="Other files" />
      <ul className="max-h-[40%] overflow-auto">
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
              {fileName(file)}
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
