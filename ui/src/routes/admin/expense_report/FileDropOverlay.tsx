import { useCallback, useEffect, useRef, useState } from "react";
import type { DragEvent, ReactNode } from "react";

// Where a file dropped now would go: a file of its own, or onto what the center pane shows.
export type HoverZone = "unlinked" | "linked" | undefined;

// Browsers send no event when a drag leaves the window, so a drag counts as over once dragover
// events stop arriving.
const STALE_MS = 200;

function carriesFiles(event: DragEvent): boolean {
  return event.dataTransfer.types.includes("Files");
}

// Takes files dropped anywhere on the editor. Each pane marks its zone with data-drop-zone.
export function FileDropOverlay({
  disabled,
  onDropUnlinked,
  onDropLinked,
  zoneOverride,
  children,
}: {
  disabled: boolean;
  onDropUnlinked: (files: File[]) => void;
  onDropLinked: (files: File[]) => void;
  // On a phone the visible pane decides the zone, as only one shows at a time.
  zoneOverride?: HoverZone;
  children: (drag: { isDragging: boolean; hoverZone: HoverZone }) => ReactNode;
}) {
  const [isDragging, setIsDragging] = useState(false);
  const [hoverZone, setHoverZone] = useState<HoverZone>();
  const lastDragOver = useRef(0);

  useEffect(() => {
    if (!isDragging) return;
    const interval = setInterval(() => {
      if (Date.now() - lastDragOver.current > STALE_MS) {
        setIsDragging(false);
        setHoverZone(undefined);
      }
    }, STALE_MS);
    return () => clearInterval(interval);
  }, [isDragging]);

  const zoneOf = useCallback(
    (event: DragEvent): HoverZone => {
      if (zoneOverride !== undefined) return zoneOverride;
      const target =
        event.target instanceof Element ? event.target.closest("[data-drop-zone]") : null;
      return target?.getAttribute("data-drop-zone") === "unlinked" ? "unlinked" : "linked";
    },
    [zoneOverride],
  );

  function handleDragOver(event: DragEvent) {
    if (disabled || !carriesFiles(event)) return;
    event.preventDefault();
    lastDragOver.current = Date.now();
    setIsDragging(true);
    setHoverZone(zoneOf(event));
  }

  function handleDrop(event: DragEvent) {
    if (disabled || !carriesFiles(event)) return;
    event.preventDefault();
    setIsDragging(false);
    setHoverZone(undefined);
    const files = Array.from(event.dataTransfer.files);
    if (files.length === 0) return;
    if (zoneOf(event) === "unlinked") onDropUnlinked(files);
    else onDropLinked(files);
  }

  return (
    <div onDragOver={handleDragOver} onDrop={handleDrop}>
      {children({ isDragging: isDragging && !disabled, hoverZone })}
    </div>
  );
}

// Covers a pane while files are dragged over the editor, saying what dropping there does.
export function DropZoneIndicator({
  visible,
  highlighted,
  label,
}: {
  visible: boolean;
  highlighted: boolean;
  label: string;
}) {
  if (!visible) return null;
  return (
    <div
      className={`absolute inset-0 z-10 flex items-center justify-center rounded-sm border-2 border-dashed px-4 py-3 text-center font-medium ${
        highlighted
          ? "border-kumo-brand bg-kumo-info-tint/95 text-kumo-strong"
          : "border-kumo-line bg-kumo-overlay/90 text-kumo-subtle"
      }`}
    >
      {label}
    </div>
  );
}
