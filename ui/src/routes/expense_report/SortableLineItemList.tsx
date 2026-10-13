import { Badge, Text } from "@cloudflare/kumo";
import { useState } from "react";
import type { DragEvent, KeyboardEvent } from "react";
import type { ExpenseLineItem } from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { formatAmountAt } from "./amounts.ts";
import { useEditor } from "./EditorContext.ts";

// A drag of a line item carries this type, which the file drop zones ignore.
const LINE_ITEM_TYPE = "application/x-sponsor-app-expense-line-item";

// Line items in their order. A drag, or Alt+Up and Alt+Down on a focused row, moves one onto
// another's place.
export function SortableLineItemList({
  items,
  decimal,
  selectedId,
  onSelect,
  onMove,
  disabled,
}: {
  items: readonly ExpenseLineItem[];
  decimal: number;
  selectedId: string | undefined;
  onSelect: (id: string) => void;
  onMove: (movedId: string, overId: string) => void;
  disabled: boolean;
}) {
  const { text } = useEditor();
  const [draggedId, setDraggedId] = useState<string>();
  const [overId, setOverId] = useState<string>();

  function endDrag() {
    setDraggedId(undefined);
    setOverId(undefined);
  }

  function handleDragOver(event: DragEvent, id: string) {
    if (draggedId === undefined || !event.dataTransfer.types.includes(LINE_ITEM_TYPE)) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = "move";
    setOverId(id);
  }

  function handleDrop(event: DragEvent, id: string) {
    if (draggedId === undefined || !event.dataTransfer.types.includes(LINE_ITEM_TYPE)) return;
    event.preventDefault();
    if (draggedId !== id) onMove(draggedId, id);
    endDrag();
  }

  function handleKeyDown(event: KeyboardEvent, index: number) {
    if (disabled || !event.altKey) return;
    const neighbour =
      items[event.key === "ArrowUp" ? index - 1 : event.key === "ArrowDown" ? index + 1 : -1];
    const item = items[index];
    if (neighbour === undefined || item === undefined) return;
    event.preventDefault();
    onMove(item.id, neighbour.id);
  }

  const draggedIndex = items.findIndex((item) => item.id === draggedId);

  return (
    <ul>
      {items.map((item, index) => {
        const isSelected = item.id === selectedId;
        const isOver = item.id === overId && item.id !== draggedId;
        // The moved item lands after the target when dragged down, before it when dragged up.
        const borders = !isOver
          ? "border-t-transparent border-b-kumo-hairline"
          : index > draggedIndex
            ? "border-t-transparent border-b-kumo-brand"
            : "border-t-kumo-brand border-b-kumo-hairline";
        return (
          <li key={item.id.toString()}>
            <button
              type="button"
              draggable={!disabled}
              onDragStart={(event) => {
                event.dataTransfer.setData(LINE_ITEM_TYPE, item.id.toString());
                event.dataTransfer.effectAllowed = "move";
                setDraggedId(item.id);
              }}
              onDragOver={(event) => handleDragOver(event, item.id)}
              onDrop={(event) => handleDrop(event, item.id)}
              onDragEnd={endDrag}
              onKeyDown={(event) => handleKeyDown(event, index)}
              onClick={() => onSelect(item.id)}
              aria-current={isSelected ? "true" : undefined}
              className={`flex w-full flex-col items-start gap-0.5 border-y-2 px-3 py-2 text-left text-sm ${borders} ${
                isSelected ? "bg-kumo-info-tint" : "hover:bg-kumo-tint"
              } ${item.id === draggedId ? "opacity-50" : ""} ${disabled ? "" : "cursor-grab"}`}
            >
              <Text bold size="sm" truncate>
                {item.title}
              </Text>
              <span className="flex flex-wrap items-center gap-1">
                <span className="font-mono text-[0.9em]">
                  {formatAmountAt(item.amount, decimal)}
                </span>
                {item.preliminal && <Badge variant="warning">{text("preliminal_badge")}</Badge>}
                {item.fileIds.length === 0 && (
                  <Badge variant="secondary">{text("no_file_badge")}</Badge>
                )}
              </span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}
