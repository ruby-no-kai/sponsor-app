import { useRef, useState } from "react";
import { problemDetailsOf } from "../../lib/errors.ts";
import { toastManager } from "../../lib/toast.ts";
import { extensionOf, postToStorage, sendToStorage } from "../../lib/upload.ts";
import type { Editor } from "./EditorContext.ts";
import { newLineItemInput } from "./lineItemForm.ts";
import type { Selection } from "./reportView.ts";
import { isAllowedFile } from "./upload.ts";

export type UploadEntry = {
  name: string;
  status: "waiting" | "uploading" | "done" | "failed" | "discarded";
  error?: string;
};

export type UploadState =
  | { kind: "idle" }
  | { kind: "active"; entries: UploadEntry[]; loaded: number; total: number; failed: boolean };

// Where uploaded files go once they are stored: onto a line item, onto a new one, or nowhere.
export type UploadTarget = { kind: "item"; id: string } | { kind: "new-item" } | { kind: "files" };

type Decision = "retry" | "discard";

// The problem's title, which the server words in the viewer's language, else the error's message.
function messageOf(error: unknown): string {
  const title = problemDetailsOf(error)?.title;
  if (title) return title;
  return error instanceof Error ? error.message : String(error);
}

// Uploads files one after another, each straight to the storage with a presigned POST. A failed
// file holds the queue until the dialog retries or discards it.
export function useFileUpload({
  editor,
  select,
}: {
  editor: Pick<
    Editor,
    "rpc" | "text" | "notify" | "applyReport" | "refreshReport" | "updateLineItem"
  >;
  select: (selection: Selection) => void;
}): {
  state: UploadState;
  start: (files: File[], destination: UploadTarget) => void;
  retry: () => void;
  discard: () => void;
} {
  const { rpc, text, notify, applyReport, refreshReport, updateLineItem } = editor;
  const [state, setState] = useState<UploadState>({ kind: "idle" });
  const decide = useRef<((decision: Decision) => void) | undefined>(undefined);

  async function run(files: File[], destination: UploadTarget) {
    const entries: UploadEntry[] = files.map((file) => ({ name: file.name, status: "waiting" }));
    const total = files.reduce((sum, file) => sum + Math.max(file.size, 1), 0);
    let completed = 0;
    const show = (loaded = 0) =>
      setState({
        kind: "active",
        entries: [...entries],
        loaded: completed + loaded,
        total,
        failed: entries.some((entry) => entry.status === "failed"),
      });
    const mark = (index: number, entry: Omit<UploadEntry, "name">) => {
      entries[index] = { name: entries[index]?.name ?? "", ...entry };
      show();
    };

    async function uploadOne(file: File, index: number): Promise<string | undefined> {
      let fileId: string | undefined;
      for (;;) {
        try {
          mark(index, { status: "uploading" });
          const upload =
            fileId === undefined
              ? await rpc.createFileUpload({ filename: file.name, contentType: file.type })
              : await rpc.initiateFileUpdate(fileId);
          fileId = upload.fileId;
          const versionId = await sendToStorage(upload, file, postToStorage, ({ loaded }) =>
            show(loaded),
          );
          await rpc.completeFileUpload({ fileId, versionId, extension: extensionOf(file.name) });
          completed += Math.max(file.size, 1);
          mark(index, { status: "done" });
          return fileId;
        } catch (error) {
          mark(index, { status: "failed", error: messageOf(error) });
          const decision = await new Promise<Decision>((resolve) => {
            decide.current = resolve;
          });
          decide.current = undefined;
          if (decision === "discard") {
            if (fileId !== undefined) {
              // A pending file left behind is never listed, so a failed delete is let go.
              await rpc.deleteFile(fileId).catch(() => undefined);
            }
            completed += Math.max(file.size, 1);
            mark(index, { status: "discarded" });
            return undefined;
          }
        }
      }
    }

    show();
    const uploaded: string[] = [];
    for (const [index, file] of files.entries()) {
      const fileId = await uploadOne(file, index);
      if (fileId !== undefined) uploaded.push(fileId);
    }
    setState({ kind: "idle" });
    if (uploaded.length > 0) await place(uploaded, destination);
  }

  async function place(fileIds: string[], destination: UploadTarget) {
    try {
      if (destination.kind === "new-item") {
        const response = await rpc.createLineItem(
          newLineItemInput(text("new_item_title"), fileIds),
        );
        applyReport(response.report);
        if (response.lineItem !== undefined) select({ kind: "item", id: response.lineItem.id });
        return;
      }

      if (destination.kind === "item") {
        const linked = await updateLineItem(destination.id, (item) => ({
          fileIds: [...item.fileIds, ...fileIds],
        }));
        if (linked) {
          select({ kind: "item", id: destination.id });
          return;
        }
      } else {
        await refreshReport();
      }
      // Files for a line item deleted meanwhile stay unattached.
      const [first] = fileIds;
      if (first !== undefined) select({ kind: "file", id: first });
    } catch (error) {
      notify(error);
    }
  }

  function start(files: File[], destination: UploadTarget) {
    if (state.kind !== "idle") return;
    const refused = files.filter((file) => !isAllowedFile(file));
    if (refused.length > 0) {
      toastManager.add({
        variant: "error",
        title: text("error_unsupported_file", {
          names: refused.map((file) => file.name).join(", "),
        }),
        description: text("supported_file_types"),
      });
    }
    const accepted = files.filter(isAllowedFile);
    if (accepted.length > 0) void run(accepted, destination);
  }

  return {
    state,
    start,
    retry: () => decide.current?.("retry"),
    discard: () => decide.current?.("discard"),
  };
}
