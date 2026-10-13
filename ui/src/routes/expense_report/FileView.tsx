import { Button, Checkbox, Text } from "@cloudflare/kumo";
import { TrashIcon } from "@phosphor-icons/react";
import { useState } from "react";
import type { ExpenseFile } from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { ConfirmAction } from "./ConfirmAction.tsx";
import { useEditor } from "./EditorContext.ts";
import { newLineItemInput } from "./lineItemForm.ts";
import { fileName } from "./reportView.ts";
import { useAction } from "./useAction.ts";

// What can be done with a file no line item attaches: make one of it, attach it, or delete it.
export function FileView({
  file,
  onSelectItem,
  onDeleted,
}: {
  file: ExpenseFile;
  onSelectItem: (id: string) => void;
  onDeleted: () => void;
}) {
  const {
    rpc,
    text,
    notify,
    report,
    isMobile,
    applyReport,
    refreshReport,
    updateLineItem,
    fileUrl,
  } = useEditor();
  const createLineItem = useAction(rpc.createLineItem);
  const [chosenIds, setChosenIds] = useState<ReadonlySet<string>>(new Set());
  const [isLinking, setIsLinking] = useState(false);
  const [isChoosing, setIsChoosing] = useState(false);
  const linkable = report.lineItems.filter((item) => !item.fileIds.includes(file.id));

  async function handleCreate() {
    try {
      const response = await createLineItem.run(
        newLineItemInput(file.filename ?? text("new_item_title"), [file.id]),
      );
      applyReport(response.report);
      if (response.lineItem !== undefined) onSelectItem(response.lineItem.id);
    } catch (error) {
      notify(error);
    }
  }

  // One update per line item, as each replaces its own list of files.
  async function handleLink() {
    setIsLinking(true);
    try {
      let firstLinked: string | undefined;
      for (const item of linkable.filter((candidate) => chosenIds.has(candidate.id))) {
        const linked = await updateLineItem(item.id, (fresh) => ({
          fileIds: fresh.fileIds.includes(file.id) ? fresh.fileIds : [...fresh.fileIds, file.id],
        }));
        if (linked) firstLinked ??= item.id;
      }
      if (firstLinked !== undefined) onSelectItem(firstLinked);
    } catch (error) {
      notify(error);
      await refreshReport();
    } finally {
      setIsLinking(false);
    }
  }

  async function handleDelete() {
    await rpc.deleteFile(file.id);
    onDeleted();
    await refreshReport();
  }

  function toggle(id: string, checked: boolean) {
    setChosenIds((current) => {
      const next = new Set(current);
      if (checked) next.add(id);
      else next.delete(id);
      return next;
    });
  }

  return (
    <div className="flex flex-col items-center gap-3 px-4 py-3 text-center">
      <Text size="sm">{fileName(file, text)}</Text>
      {isMobile && (
        <Button
          variant="secondary"
          size="sm"
          onClick={() => window.open(fileUrl(file.id), "_blank", "noopener,noreferrer")}
        >
          {text("preview_file")}
        </Button>
      )}
      <Button
        variant="primary"
        size="sm"
        loading={createLineItem.isRunning}
        onClick={() => void handleCreate()}
      >
        {text("create_from_file")}
      </Button>

      {linkable.length > 0 &&
        (isChoosing ? (
          <div className="flex w-full max-w-xs flex-col gap-2 text-left">
            <Text bold size="sm">
              {text("link_to_existing_items")}
            </Text>
            <ul className="flex max-h-52 flex-col overflow-auto rounded-lg border border-kumo-line p-1">
              {linkable.map((item) => (
                <li key={item.id.toString()} className="rounded-sm px-2 py-1 hover:bg-kumo-tint">
                  <Checkbox
                    label={item.title}
                    checked={chosenIds.has(item.id)}
                    onCheckedChange={(checked) => toggle(item.id, checked)}
                    disabled={isLinking}
                  />
                </li>
              ))}
            </ul>
            <Button
              variant="secondary"
              size="sm"
              loading={isLinking}
              disabled={chosenIds.size === 0}
              onClick={() => void handleLink()}
            >
              {text("link_selected")}
            </Button>
          </div>
        ) : (
          <Button variant="secondary" size="sm" onClick={() => setIsChoosing(true)}>
            {text("link_to_existing_items")}
          </Button>
        ))}

      <hr className="w-full border-kumo-line" />
      <ConfirmAction
        label={text("delete_file")}
        icon={TrashIcon}
        size="sm"
        title={text("confirm_delete_file")}
        description={fileName(file, text)}
        confirmLabel={text("delete")}
        cancelLabel={text("review_dialog_cancel")}
        onError={notify}
        onConfirm={handleDelete}
      />
    </div>
  );
}
