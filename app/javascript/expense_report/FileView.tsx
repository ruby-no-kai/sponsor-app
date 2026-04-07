import { useState } from "react";
import type { ExpenseReport } from "./types";
import { deleteFile, createLineItem } from "./api";
import { useI18n } from "./I18nContext";

type FileViewProps = {
  file: ExpenseReport["files"][number];
  filesUrl: string;
  lineItemsUrl: string;
  onUpdate: (r: ExpenseReport) => void;
  onError: (e: string) => void;
  onPreviewFile: (id: number | null) => void;
  onSelectItem: (id: number) => void;
  onRefresh: () => void;
  isMobile: boolean;
};

export function FileView({
  file,
  filesUrl,
  lineItemsUrl,
  onUpdate,
  onError,
  onPreviewFile,
  onSelectItem,
  onRefresh,
  isMobile,
}: FileViewProps) {
  const i18n = useI18n();
  const [creatingFromFile, setCreatingFromFile] = useState(false);
  const [deletingFile, setDeletingFile] = useState(false);

  const handleDeleteFile = async () => {
    if (!confirm(i18n.confirm_delete_file)) return;
    setDeletingFile(true);
    try {
      await deleteFile(filesUrl, file.id);
      onPreviewFile(null);
      onRefresh();
    } catch (e) {
      onError(e instanceof Error ? e.message : i18n.error_delete);
    } finally {
      setDeletingFile(false);
    }
  };

  const handleCreateFromFile = async () => {
    setCreatingFromFile(true);
    try {
      const result = await createLineItem(lineItemsUrl, {
        title: file.filename || "New expense",
        amount: "0",
        tax_amount: "0",
        file_ids: [file.id],
      });
      onUpdate(result);
      const newItem = result.line_items[result.line_items.length - 1];
      if (newItem) onSelectItem(newItem.id);
    } catch (e) {
      onError(e instanceof Error ? e.message : i18n.error_create);
    } finally {
      setCreatingFromFile(false);
    }
  };

  return (
    <div className="text-center">
      <p className="mb-2 small">{file.filename}</p>
      {isMobile && (
        <button
          className="btn btn-outline-secondary btn-sm mb-2"
          onClick={() => window.open(`${filesUrl}/${file.id}`, "_blank")}
        >
          {i18n.preview_file}
        </button>
      )}
      <br />
      <button
        className="btn btn-primary btn-sm mb-2"
        onClick={handleCreateFromFile}
        disabled={creatingFromFile}
      >
        {creatingFromFile ? i18n.creating : i18n.create_from_file}
      </button>
      <br />
      <button
        className="btn btn-outline-danger btn-sm"
        onClick={handleDeleteFile}
        disabled={deletingFile}
      >
        {deletingFile ? i18n.deleting : i18n.delete_file}
      </button>
    </div>
  );
}
