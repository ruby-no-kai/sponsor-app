import { Link, Text } from "@cloudflare/kumo";
import type { ReactNode } from "react";
import type { ExpenseFile } from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { useEditor } from "./EditorContext.ts";
import { PaneHeader } from "./EditorParts.tsx";
import { fileName } from "./reportView.ts";

// Previews a file through a page that redirects to the storage.
export function RightPane({
  file,
  dropIndicator,
}: {
  file: ExpenseFile | undefined;
  dropIndicator: ReactNode;
}) {
  const { text, fileUrl } = useEditor();

  if (file === undefined) {
    return (
      <div data-drop-zone="linked" className="relative border-l border-kumo-line">
        <div className="sticky top-4 flex h-[calc(100dvh-12rem)] min-h-64 items-center justify-center">
          <Text variant="secondary">{text("select_file")}</Text>
        </div>
        {dropIndicator}
      </div>
    );
  }

  const url = fileUrl(file.id);
  const name = fileName(file, text);
  return (
    <div data-drop-zone="linked" className="relative border-l border-kumo-line">
      <div className="sticky top-4 flex h-[calc(100dvh-12rem)] min-h-64 flex-col">
        <PaneHeader title={name} />
        <div className="flex min-h-0 flex-1 items-center justify-center overflow-auto p-2">
          {file.contentType.startsWith("image/") ? (
            <img src={url} alt={name} className="max-h-full max-w-full" />
          ) : file.contentType === "application/pdf" ? (
            <iframe src={url} title={name} className="size-full border-0" />
          ) : (
            <Text variant="secondary" size="sm">
              {text("no_preview")}{" "}
              <Link href={url} target="_blank" rel="noreferrer">
                {text("download")}
              </Link>
            </Text>
          )}
        </div>
      </div>
      {dropIndicator}
    </div>
  );
}
