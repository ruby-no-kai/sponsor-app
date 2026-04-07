import { useState } from "react";
import type { ExpenseReport } from "./types";
import { deleteFile, createLineItem, updateLineItem } from "./api";
import { useI18n } from "./I18nContext";

type FileViewProps = {
  file: ExpenseReport["files"][number];
  report: ExpenseReport;
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
  report,
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
  const [selectedItemIds, setSelectedItemIds] = useState<Set<number>>(new Set());
  const [linking, setLinking] = useState(false);
  const [linkMenuOpen, setLinkMenuOpen] = useState(false);

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

  const toggleItemId = (id: number) => {
    setSelectedItemIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const handleLinkToItems = async () => {
    if (selectedItemIds.size === 0) return;
    setLinking(true);
    try {
      let result: ExpenseReport | null = null;
      for (const itemId of selectedItemIds) {
        const item = report.line_items.find((i) => i.id === itemId);
        if (!item || item.file_ids.includes(file.id)) continue;
        result = await updateLineItem(lineItemsUrl, itemId, {
          file_ids: [...item.file_ids, file.id],
        });
      }
      if (result) {
        onUpdate(result);
        onSelectItem([...selectedItemIds][0]);
      }
      setSelectedItemIds(new Set());
    } catch (e) {
      onError(e instanceof Error ? e.message : i18n.error_save);
    } finally {
      setLinking(false);
    }
  };

  const linkableItems = report.line_items.filter((i) => !i.file_ids.includes(file.id));

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

      {linkableItems.length > 0 && (
        <div className="mt-3 text-left" style={{ maxWidth: "300px", margin: "0 auto" }}>
          {!linkMenuOpen ? (
            <button
              className="btn btn-outline-secondary btn-sm btn-block"
              onClick={() => setLinkMenuOpen(true)}
            >
              {i18n.link_to_existing_items}
            </button>
          ) : (
            <>
              <label className="small font-weight-bold d-block text-center mb-1">
                {i18n.link_to_existing_items}
              </label>
              <div
                className="border rounded mb-2"
                style={{ maxHeight: "200px", overflowY: "auto" }}
              >
                {linkableItems.map((item) => (
                  <label
                    key={item.id}
                    className="d-flex align-items-center small px-2 py-1 mb-0 border-bottom"
                    style={{ cursor: "pointer" }}
                  >
                    <input
                      type="checkbox"
                      className="mr-2"
                      checked={selectedItemIds.has(item.id)}
                      onChange={() => toggleItemId(item.id)}
                      disabled={linking}
                    />
                    <span className="text-truncate">{item.title}</span>
                  </label>
                ))}
              </div>
              <button
                className="btn btn-outline-primary btn-sm btn-block"
                onClick={handleLinkToItems}
                disabled={linking || selectedItemIds.size === 0}
              >
                {linking ? i18n.saving : i18n.link_selected}
              </button>
            </>
          )}
        </div>
      )}

      <hr />
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
