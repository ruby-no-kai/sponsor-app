import { Text } from "@cloudflare/kumo";
import { useRef } from "react";
import type { ReactNode } from "react";
import { ALLOWED_CONTENT_TYPES } from "./upload.ts";

export function PaneHeader({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-2 border-b border-kumo-line bg-kumo-recessed px-3 py-2">
      <Text bold size="sm">
        {title}
      </Text>
      {children}
    </div>
  );
}

// A dashed box offering the file picker beside dropping.
export function UploadHint({
  prompt,
  onUploadFiles,
  children,
}: {
  prompt: string;
  onUploadFiles: (files: File[]) => void;
  children?: ReactNode;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  return (
    <div className="m-1 flex flex-col gap-2 rounded-md border border-dashed border-kumo-line p-2 text-center text-sm text-kumo-subtle">
      <div>
        {prompt}{" "}
        <button
          type="button"
          className="text-kumo-link underline"
          onClick={() => inputRef.current?.click()}
        >
          upload
        </button>
      </div>
      <input
        ref={inputRef}
        type="file"
        accept={ALLOWED_CONTENT_TYPES.join(",")}
        multiple
        className="hidden"
        onChange={(event) => {
          const files = Array.from(event.target.files ?? []);
          if (files.length > 0) onUploadFiles(files);
          event.target.value = "";
        }}
      />
      {children}
    </div>
  );
}
