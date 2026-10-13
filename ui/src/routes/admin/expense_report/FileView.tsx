import { Button, Checkbox, Text } from "@cloudflare/kumo";
import { useState } from "react";
import { AdminService } from "../../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import type { ExpenseFile } from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { useRpcMutation } from "../../../lib/rpc.ts";
import { notifyError } from "../../../lib/toast.ts";
import { useEditor } from "./EditorContext.ts";
import { newLineItemInput } from "./lineItemForm.ts";
import { fileName } from "./reportView.ts";

// What can be done with a file no line item attaches: make one of it or attach it.
export function FileView({
  file,
  onSelectItem,
}: {
  file: ExpenseFile;
  onSelectItem: (id: string) => void;
}) {
  const { target, report, isMobile, applyReport, refreshReport, updateLineItem, fileUrl } =
    useEditor();
  const createLineItem = useRpcMutation(AdminService.method.createExpenseLineItem);
  const [chosenIds, setChosenIds] = useState<ReadonlySet<string>>(new Set());
  const [isLinking, setIsLinking] = useState(false);
  const [isChoosing, setIsChoosing] = useState(false);
  const linkable = report.lineItems.filter((item) => !item.fileIds.includes(file.id));

  async function handleCreate() {
    try {
      const response = await createLineItem.trigger({
        ...target,
        input: newLineItemInput(file.filename ?? "New expense", [file.id]),
      });
      applyReport(response.report);
      if (response.lineItem !== undefined) onSelectItem(response.lineItem.id);
    } catch (error) {
      notifyError(error);
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
      notifyError(error);
      await refreshReport();
    } finally {
      setIsLinking(false);
    }
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
    <div className="flex flex-col items-center gap-3 p-4 text-center">
      <Text size="sm">{fileName(file)}</Text>
      {isMobile && (
        <Button
          variant="secondary"
          size="sm"
          onClick={() => window.open(fileUrl(file.id), "_blank", "noopener,noreferrer")}
        >
          Preview file
        </Button>
      )}
      <Button
        variant="primary"
        size="sm"
        loading={createLineItem.isMutating}
        onClick={() => void handleCreate()}
      >
        Create line item from this file
      </Button>

      {linkable.length > 0 &&
        (isChoosing ? (
          <div className="flex w-full max-w-xs flex-col gap-2 text-left">
            <Text bold size="sm">
              Link to existing line items
            </Text>
            <ul className="flex max-h-52 flex-col gap-1 overflow-auto rounded-md border border-kumo-line p-2">
              {linkable.map((item) => (
                <li key={item.id.toString()}>
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
              Link selected
            </Button>
          </div>
        ) : (
          <Button variant="secondary" size="sm" onClick={() => setIsChoosing(true)}>
            Link to existing line items
          </Button>
        ))}
    </div>
  );
}
