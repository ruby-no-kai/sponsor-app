import React from "react";
import { createRoot } from "react-dom/client";
import { ExpenseReportEditor } from "./expense_report/ExpenseReportEditor";
import type { EditorProps } from "./expense_report/types";

document.addEventListener("DOMContentLoaded", () => {
  const container = document.getElementById("expense-report-editor");
  if (!container) return;

  const dataset = container.dataset;
  const props: EditorProps = {
    role: (dataset.role as EditorProps["role"]) || "sponsor",
    reportUrl: dataset.reportUrl || "",
    lineItemsUrl: dataset.lineItemsUrl || "",
    submissionUrl: dataset.submissionUrl,
    reviewsUrl: dataset.reviewsUrl,
    calculateUrl: dataset.calculateUrl || "",
    filesUrl: dataset.filesUrl || "",
    csrfToken: dataset.csrfToken || "",
  };

  const root = createRoot(container);
  root.render(<ExpenseReportEditor {...props} />);
});
