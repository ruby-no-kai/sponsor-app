import React from "react";
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from "@dnd-kit/core";
import type { DragEndEvent } from "@dnd-kit/core";
import {
  SortableContext,
  sortableKeyboardCoordinates,
  verticalListSortingStrategy,
  useSortable,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import type { ExpenseLineItem } from "./types";
import { useI18n } from "./I18nContext";

type SortableLineItemListProps = {
  items: ExpenseLineItem[];
  selectedItemId: number | null;
  onSelectItem: (id: number) => void;
  onReorder: (activeId: number, overId: number) => void;
  disabled: boolean;
  isMobile: boolean;
};

export function SortableLineItemList({
  items,
  selectedItemId,
  onSelectItem,
  onReorder,
  disabled,
  isMobile,
}: SortableLineItemListProps) {
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  );

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    if (over && active.id !== over.id) {
      onReorder(active.id as number, over.id as number);
    }
  };

  if (disabled || isMobile) {
    return (
      <>
        {items.map((item) => (
          <div key={item.id} onClick={() => onSelectItem(item.id)} style={{ cursor: "pointer" }}>
            <LineItemRow item={item} isSelected={selectedItemId === item.id} />
          </div>
        ))}
      </>
    );
  }

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
      <SortableContext items={items.map((i) => i.id)} strategy={verticalListSortingStrategy}>
        {items.map((item) => (
          <SortableLineItem
            key={item.id}
            item={item}
            isSelected={selectedItemId === item.id}
            onClick={() => onSelectItem(item.id)}
          />
        ))}
      </SortableContext>
    </DndContext>
  );
}

function SortableLineItem({
  item,
  isSelected,
  onClick,
}: {
  item: ExpenseLineItem;
  isSelected: boolean;
  onClick: () => void;
}) {
  const { attributes, listeners, setNodeRef, transform, transition } = useSortable({ id: item.id });

  const style: React.CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition: transition || undefined,
    cursor: "pointer",
  };

  return (
    <div ref={setNodeRef} style={style} {...attributes} {...listeners} onClick={onClick}>
      <LineItemRow item={item} isSelected={isSelected} />
    </div>
  );
}

function LineItemRow({ item, isSelected }: { item: ExpenseLineItem; isSelected: boolean }) {
  const i18n = useI18n();
  const num = parseFloat(item.amount);
  const formatted = isNaN(num) ? item.amount : num.toLocaleString();

  return (
    <div className={`p-2 border-bottom ${isSelected ? "bg-primary text-white" : ""}`}>
      <div className="small font-weight-bold text-truncate">{item.title}</div>
      <div className="small">
        {formatted}
        {item.preliminal && (
          <span className={`ml-1 badge ${isSelected ? "badge-light" : "badge-warning"}`}>
            {i18n.preliminal_badge}
          </span>
        )}
        {item.file_ids.length === 0 && (
          <span className={`ml-1 badge ${isSelected ? "badge-light" : "badge-danger"}`}>
            {i18n.no_file_badge}
          </span>
        )}
      </div>
    </div>
  );
}
