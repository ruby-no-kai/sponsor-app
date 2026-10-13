import { Button, Text } from "@cloudflare/kumo";
import { UploadSimpleIcon } from "@phosphor-icons/react";
import { useRef } from "react";
import { formatFileSize } from "./upload.ts";

// A button that opens the browser's file dialog, and the file chosen with its size and a way to
// drop it. The native input stays hidden, as it words its state in the browser's language.
export function FilePicker({
  file,
  accept,
  label,
  chooseLabel,
  removeLabel,
  disabled = false,
  onChoose,
}: {
  file: File | undefined;
  accept: string;
  // Names the input for assistive technology.
  label: string;
  chooseLabel: string;
  removeLabel: string;
  disabled?: boolean;
  // Called with the file picked, or undefined when the chosen file is removed.
  onChoose: (file: File | undefined) => void;
}) {
  const input = useRef<HTMLInputElement>(null);

  return (
    <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
      <input
        ref={input}
        type="file"
        accept={accept}
        aria-label={label}
        hidden
        disabled={disabled}
        onChange={(event) => {
          const picked = event.currentTarget.files?.[0];
          // Picking the same file again must still fire a change.
          event.currentTarget.value = "";
          if (picked !== undefined) onChoose(picked);
        }}
      />
      <Button
        variant="secondary"
        size="sm"
        icon={UploadSimpleIcon}
        disabled={disabled}
        onClick={() => input.current?.click()}
      >
        {chooseLabel}
      </Button>
      {file !== undefined && (
        <>
          <Text as="span" DANGEROUS_className="min-w-0 break-all">
            {file.name} <span className="text-kumo-subtle">({formatFileSize(file.size)})</span>
          </Text>
          <Button variant="ghost" size="sm" disabled={disabled} onClick={() => onChoose(undefined)}>
            {removeLabel}
          </Button>
        </>
      )}
    </div>
  );
}
