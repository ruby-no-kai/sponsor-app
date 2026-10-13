import { createContext, useContext } from "react";
import type {
  ExpenseLineItem,
  ExpenseReport,
} from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type { ExpenseRpc } from "./expenseRpc.ts";
import type { LineItemInputInit, Rounding } from "./lineItemForm.ts";
import type { Role } from "./reportView.ts";
import type { EditorText } from "./text.ts";

// What every pane of the editor reads and acts through.
export type Editor = {
  role: Role;
  rpc: ExpenseRpc;
  text: EditorText;
  // Reports a failed action, in the language the editor speaks.
  notify: (error: unknown) => void;
  report: ExpenseReport;
  rounding: Rounding;
  readOnly: boolean;
  isMobile: boolean;
  // Shows a report as an RPC answered it.
  applyReport: (report: ExpenseReport | undefined) => void;
  // Reads the report again, after an RPC that answers none.
  refreshReport: () => Promise<void>;
  // Changes some fields of a line item and shows the report as changed. An update replaces every
  // field, so the others come from a fresh read rather than the report shown, which may be stale.
  // False when the line item is gone.
  updateLineItem: (
    lineItemId: string,
    change: (item: ExpenseLineItem) => LineItemInputInit,
  ) => Promise<boolean>;
  // The page redirecting to the file in the storage, for previews and downloads.
  fileUrl: (fileId: string) => string;
};

const EditorContext = createContext<Editor | undefined>(undefined);

export const EditorProvider = EditorContext.Provider;

export function useEditor(): Editor {
  const editor = useContext(EditorContext);
  if (editor === undefined) throw new Error("useEditor is used outside ExpenseReportEditor");
  return editor;
}
