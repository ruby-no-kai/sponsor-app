import { Link, Text } from "@cloudflare/kumo";
import type { ReactNode } from "react";
import type { ExpenseFile } from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { useEditor } from "./EditorContext.ts";
import { PaneHeader } from "./EditorParts.tsx";
import { fileName } from "./reportView.ts";

// Previews a file through the staff area's file page, which redirects to the storage.
export function RightPane({
  file,
  dropIndicator,
}: {
  file: ExpenseFile | undefined;
  dropIndicator: ReactNode;
}) {
  const { fileUrl } = useEditor();

  if (file === undefined) {
    return (
      <div
        data-drop-zone="linked"
        className="relative flex flex-[5_0_0] items-center justify-center border-l border-kumo-line"
      >
        <Text variant="secondary">Select a file to preview</Text>
        {dropIndicator}
      </div>
    );
  }

  const url = fileUrl(file.id);
  const name = fileName(file);
  return (
    <div
      data-drop-zone="linked"
      className="relative flex min-w-72 flex-[5_0_0] flex-col border-l border-kumo-line"
    >
      <PaneHeader title={name} />
      <div className="flex min-h-0 flex-1 items-center justify-center overflow-auto p-2">
        {file.contentType.startsWith("image/") ? (
          <img src={url} alt={name} className="max-h-full max-w-full" />
        ) : file.contentType === "application/pdf" ? (
          <iframe src={url} title={name} className="size-full border-0" />
        ) : (
          <Text variant="secondary" size="sm">
            Preview not available.{" "}
            <Link href={url} target="_blank" rel="noreferrer">
              Download
            </Link>
          </Text>
        )}
      </div>
      {dropIndicator}
    </div>
  );
}
