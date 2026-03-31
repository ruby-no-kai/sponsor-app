import React, { useState, useCallback } from "react";
import type { ReactNode } from "react";

type FileDropZoneProps = {
  onFilesDropped: (files: File[]) => void;
  disabled?: boolean;
  children: ReactNode;
  className?: string;
  style?: React.CSSProperties;
};

export function FileDropZone({
  onFilesDropped,
  disabled,
  children,
  className,
  style,
}: FileDropZoneProps) {
  const [isDragOver, setIsDragOver] = useState(false);

  const handleDragOver = useCallback(
    (e: React.DragEvent) => {
      if (disabled) return;
      e.preventDefault();
      e.stopPropagation();
      setIsDragOver(true);
    },
    [disabled],
  );

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragOver(false);
  }, []);

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      e.stopPropagation();
      setIsDragOver(false);
      if (disabled) return;

      const files = Array.from(e.dataTransfer.files);
      if (files.length > 0) {
        onFilesDropped(files);
      }
    },
    [disabled, onFilesDropped],
  );

  return (
    <div
      className={className}
      style={{
        ...style,
        outline: isDragOver ? "2px dashed #007bff" : undefined,
        backgroundColor: isDragOver ? "rgba(0,123,255,0.05)" : undefined,
      }}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      {children}
    </div>
  );
}
