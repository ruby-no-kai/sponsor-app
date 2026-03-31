import React, { useState, useCallback, useRef, useEffect } from "react";
import type { ExpenseLineItem } from "./types";

type FileDropOverlayProps = {
  selectedItem: ExpenseLineItem | null;
  disabled: boolean;
  onDropUnlinked: (files: File[]) => void;
  onDropLinked: (files: File[]) => void;
  children: React.ReactNode;
};

type HoverZone = "unlinked" | "linked" | null;

const STALE_MS = 200;

export function FileDropOverlay({
  selectedItem,
  disabled,
  onDropUnlinked,
  onDropLinked,
  children,
}: FileDropOverlayProps) {
  const [isDragging, setIsDragging] = useState(false);
  const [hoverZone, setHoverZone] = useState<HoverZone>(null);
  const lastDragOverRef = useRef(0);
  const isDraggingRef = useRef(false);
  const overlayRef = useRef<HTMLDivElement>(null);

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

  // Determine zone from mouse X position relative to the overlay
  const zoneFromEvent = useCallback((e: React.DragEvent): HoverZone => {
    const el = overlayRef.current;
    if (!el) return "unlinked";
    const rect = el.getBoundingClientRect();
    const relX = e.clientX - rect.left;
    return relX < rect.width / 2 ? "unlinked" : "linked";
  }, []);

  const hoverZoneRef = useRef<HoverZone>(null);

  const handleDragOver = useCallback(
    (e: React.DragEvent) => {
      if (disabled) return;
      e.preventDefault();
      lastDragOverRef.current = Date.now();

      const zone = zoneFromEvent(e);

      // Batch: only update state when something actually changed
      const needsDragging = !isDraggingRef.current;
      const needsZone = zone !== hoverZoneRef.current;

      if (needsDragging) {
        isDraggingRef.current = true;
      }
      if (needsZone) {
        hoverZoneRef.current = zone;
      }
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

      if (zone === "linked" && selectedItem) {
        onDropLinked(files);
      } else {
        onDropUnlinked(files);
      }
    },
    [zoneFromEvent, selectedItem, onDropLinked, onDropUnlinked],
  );

  const linkedEnabled = selectedItem !== null;

  return (
    <div
      ref={overlayRef}
      style={{ position: "relative" }}
      onDragOver={handleDragOver}
      onDrop={handleDrop}
    >
      {children}

      {isDragging && !disabled && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            zIndex: 100,
            display: "flex",
            gap: "4px",
            padding: "4px",
            backgroundColor: "rgba(0,0,0,0.3)",
          }}
        >
          <ZoneIndicator label="Add as unlinked file" isHover={hoverZone === "unlinked"} enabled />
          <ZoneIndicator
            label={selectedItem ? `Link to "${selectedItem.title}"` : "Select a line item first"}
            isHover={hoverZone === "linked"}
            enabled={linkedEnabled}
          />
        </div>
      )}
    </div>
  );
}

function ZoneIndicator({
  label,
  isHover,
  enabled,
}: {
  label: string;
  isHover: boolean;
  enabled: boolean;
}) {
  return (
    <div
      style={{
        flex: 1,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        border: `3px dashed ${isHover && enabled ? "#007bff" : enabled ? "rgba(255,255,255,0.6)" : "rgba(255,255,255,0.2)"}`,
        borderRadius: "8px",
        backgroundColor: isHover && enabled ? "rgba(0,123,255,0.15)" : "transparent",
        color: enabled ? "white" : "rgba(255,255,255,0.4)",
        fontSize: "1rem",
        fontWeight: "bold",
        textAlign: "center",
        padding: "1rem",
      }}
    >
      {label}
    </div>
  );
}
