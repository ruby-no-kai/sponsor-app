import React, { useState, useCallback, useRef, useEffect } from "react";
import type { ExpenseLineItem } from "./types";

export type HoverZone = "unlinked" | "linked" | null;

type FileDropOverlayProps = {
  selectedItem: ExpenseLineItem | null;
  disabled: boolean;
  onDropUnlinked: (files: File[]) => void;
  onDropLinked: (files: File[]) => void;
  children: (dragState: { isDragging: boolean; hoverZone: HoverZone }) => React.ReactNode;
  isMobile: boolean;
  mobileView: "list" | "detail";
};

const STALE_MS = 200;

export function FileDropOverlay({
  selectedItem,
  disabled,
  onDropUnlinked,
  onDropLinked,
  children,
  isMobile,
  mobileView,
}: FileDropOverlayProps) {
  const [isDragging, setIsDragging] = useState(false);
  const [hoverZone, setHoverZone] = useState<HoverZone>(null);
  const lastDragOverRef = useRef(0);
  const isDraggingRef = useRef(false);
  const overlayRef = useRef<HTMLDivElement>(null);
  const hoverZoneRef = useRef<HoverZone>(null);

  useEffect(() => {
    if (!isDragging) return;
    const interval = setInterval(() => {
      if (Date.now() - lastDragOverRef.current > STALE_MS) {
        isDraggingRef.current = false;
        hoverZoneRef.current = null;
        setIsDragging(false);
        setHoverZone(null);
      }
    }, STALE_MS);
    return () => clearInterval(interval);
  }, [isDragging]);

  const zoneFromEvent = useCallback(
    (e: React.DragEvent): HoverZone => {
      if (isMobile) {
        return mobileView === "list" ? "unlinked" : "linked";
      }
      const el = overlayRef.current;
      if (!el) return "unlinked";
      const rect = el.getBoundingClientRect();
      const relX = e.clientX - rect.left;
      return relX < rect.width / 3 ? "unlinked" : "linked";
    },
    [isMobile, mobileView],
  );

  const handleDragOver = useCallback(
    (e: React.DragEvent) => {
      if (disabled) return;
      e.preventDefault();
      lastDragOverRef.current = Date.now();

      const zone = zoneFromEvent(e);
      const needsDragging = !isDraggingRef.current;
      const needsZone = zone !== hoverZoneRef.current;

      if (needsDragging) isDraggingRef.current = true;
      if (needsZone) hoverZoneRef.current = zone;
      if (needsDragging || needsZone) {
        if (needsDragging) setIsDragging(true);
        if (needsZone) setHoverZone(zone);
      }
    },
    [disabled, zoneFromEvent],
  );

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      isDraggingRef.current = false;
      hoverZoneRef.current = null;
      setIsDragging(false);

      const files = Array.from(e.dataTransfer.files);
      if (files.length === 0) {
        setHoverZone(null);
        return;
      }

      const zone = zoneFromEvent(e);
      setHoverZone(null);

      if (zone === "linked") {
        onDropLinked(files);
      } else {
        onDropUnlinked(files);
      }
    },
    [zoneFromEvent, selectedItem, onDropLinked, onDropUnlinked],
  );

  return (
    <div ref={overlayRef} onDragOver={handleDragOver} onDrop={handleDrop}>
      {children({ isDragging: isDragging && !disabled, hoverZone })}
    </div>
  );
}

export function DropZoneIndicator({
  visible,
  highlighted,
  label,
  enabled = true,
}: {
  visible: boolean;
  highlighted: boolean;
  label: string;
  enabled?: boolean;
}) {
  if (!visible) return null;

  const isActive = highlighted && enabled;

  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        zIndex: 100,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        border: `3px dashed ${isActive ? "#007bff" : enabled ? "rgba(0,0,0,0.3)" : "rgba(0,0,0,0.15)"}`,
        borderRadius: "4px",
        backgroundColor: isActive ? "rgba(0,123,255,0.25)" : "rgba(0,0,0,0.08)",
        color: isActive ? "#004085" : enabled ? "rgba(0,0,0,0.5)" : "rgba(0,0,0,0.25)",
        fontSize: "1rem",
        fontWeight: "bold",
        textAlign: "center",
      }}
    >
      {label}
    </div>
  );
}
