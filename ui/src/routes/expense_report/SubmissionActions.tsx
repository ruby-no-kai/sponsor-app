import { Banner, Button, Dialog, Text } from "@cloudflare/kumo";
import { WarningIcon } from "@phosphor-icons/react";
import { useState } from "react";
import type {
  ExpenseReport,
  ExpenseReportCalculation,
} from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { ExpenseReport_Status } from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { formatAmountAt } from "./amounts.ts";
import { ConfirmAction } from "./ConfirmAction.tsx";
import { useEditor } from "./EditorContext.ts";
import type { SubmissionRpc } from "./expenseRpc.ts";
import { fileName, submissionChecks } from "./reportView.ts";

// What a sponsor does with a report: submit a draft, take a submission back, or what comes next
// for one the organizers have decided on.
export function SubmissionActions({
  submission,
  calculation,
}: {
  submission: SubmissionRpc;
  calculation: ExpenseReportCalculation;
}) {
  const { report, text, notify, applyReport, refreshReport } = useEditor();

  if (report.status === ExpenseReport_Status.DRAFT) {
    return (
      <SubmitButton
        submission={submission}
        calculation={calculation}
        report={report}
        onSubmitted={applyReport}
        onFailed={(error) => {
          notify(error);
          void refreshReport();
        }}
      />
    );
  }
  if (report.status === ExpenseReport_Status.SUBMITTED) {
    return (
      <ConfirmAction
        variant="secondary"
        confirmVariant="primary"
        label={text("withdraw")}
        title={text("withdraw")}
        description={text("confirm_withdraw")}
        confirmLabel={text("withdraw")}
        cancelLabel={text("review_dialog_cancel")}
        onError={(error) => {
          notify(error);
          void refreshReport();
        }}
        onConfirm={async () => applyReport(await submission.withdraw())}
      />
    );
  }
  // The server submits only a draft, and a change to a rejected report makes it one.
  if (report.status === ExpenseReport_Status.REJECTED) {
    return <Text variant="secondary">{text("rejected_next_step")}</Text>;
  }
  if (report.status === ExpenseReport_Status.APPROVED) {
    return <Text variant="secondary">{text("approved_locked")}</Text>;
  }
  return null;
}

function SubmitButton({
  submission,
  calculation,
  report,
  onSubmitted,
  onFailed,
}: {
  submission: SubmissionRpc;
  calculation: ExpenseReportCalculation;
  report: ExpenseReport;
  onSubmitted: (report: ExpenseReport | undefined) => void;
  onFailed: (error: unknown) => void;
}) {
  const { text } = useEditor();
  const [open, setOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleConfirm() {
    setIsSubmitting(true);
    try {
      onSubmitted(await submission.submit());
      setOpen(false);
    } catch (error) {
      setOpen(false);
      onFailed(error);
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <>
      <Button variant="primary" onClick={() => setOpen(true)}>
        {text("submit")}
      </Button>
      <Dialog.Root open={open} onOpenChange={(next) => !isSubmitting && setOpen(next)}>
        <Dialog className="flex max-h-[85vh] flex-col gap-4 overflow-auto px-6 py-5" size="lg">
          <Dialog.Title className="text-lg font-semibold">
            {text("review_dialog_title")}
          </Dialog.Title>
          <SubmissionSummary report={report} calculation={calculation} />
          <div className="flex justify-end gap-2">
            <Button variant="secondary" disabled={isSubmitting} onClick={() => setOpen(false)}>
              {text("review_dialog_cancel")}
            </Button>
            <Button variant="primary" loading={isSubmitting} onClick={() => void handleConfirm()}>
              {isSubmitting ? text("submitting") : text("submit")}
            </Button>
          </div>
        </Dialog>
      </Dialog.Root>
    </>
  );
}

// The line items by the files they attach, the files left over, and the figures, with a warning for
// each thing the organizers would raise.
function SubmissionSummary({
  report,
  calculation,
}: {
  report: ExpenseReport;
  calculation: ExpenseReportCalculation;
}) {
  const { text } = useEditor();
  const { decimal } = calculation;
  const checks = submissionChecks(report, calculation.totalFee);
  const filesById = new Map(report.files.map((file) => [file.id, file]));

  return (
    <div className="flex flex-col gap-4">
      {checks.groups.map((group) => (
        <div key={group.key} className="flex flex-col gap-1">
          <Text variant="secondary" size="sm" bold>
            {group.fileIds.length === 0
              ? text("review_dialog_no_files")
              : group.fileIds
                  .map((id) => {
                    const file = filesById.get(id);
                    return file === undefined
                      ? text("file_fallback_name", { id })
                      : fileName(file, text);
                  })
                  .join(", ")}
          </Text>
          {group.items.map((item) => (
            <div
              key={item.id}
              className="flex items-center justify-between gap-2 border-l-2 border-kumo-line pl-2 text-sm"
            >
              <span className="min-w-0 break-words">
                {item.title}
                {item.preliminal && (
                  <span className="ml-1 text-kumo-warning">({text("preliminal_badge")})</span>
                )}
                {item.fileIds.length === 0 && (
                  <span className="ml-1 text-kumo-subtle">({text("no_file_badge")})</span>
                )}
              </span>
              <span className="whitespace-nowrap font-mono text-[0.9em] font-medium">
                {formatAmountAt(item.amount, decimal)}
              </span>
            </div>
          ))}
        </div>
      ))}

      {checks.unlinkedFiles.length > 0 && (
        <div className="flex flex-col gap-1">
          <Text variant="secondary" size="sm" bold>
            {text("review_dialog_unlinked_files")}
          </Text>
          {checks.unlinkedFiles.map((file) => (
            <Text key={file.id} variant="secondary" size="sm">
              {fileName(file, text)}
            </Text>
          ))}
        </div>
      )}

      <hr className="border-kumo-line" />

      <dl className="grid grid-cols-[1fr_max-content] gap-x-3 gap-y-1 text-sm">
        <dt className="text-kumo-subtle">{text("review_dialog_base_fee")}</dt>
        <dd className="text-right font-mono text-[0.9em] font-medium">
          {formatAmountAt(calculation.totalFee, decimal)}
        </dd>
        <dt className="text-kumo-subtle">{text("review_dialog_total_expense")}</dt>
        <dd className="text-right font-mono text-[0.9em] font-medium">
          {formatAmountAt(report.totalAmount, decimal)}
        </dd>
        {checks.remaining !== undefined && (
          <>
            <dt className="text-kumo-subtle">{text("review_dialog_remaining")}</dt>
            <dd
              className={`text-right font-mono text-[0.9em] font-medium ${checks.overage ? "text-kumo-danger" : ""}`}
            >
              {formatAmountAt(checks.remaining, decimal)}
            </dd>
          </>
        )}
      </dl>

      {checks.overage && (
        <Banner
          variant="alert"
          icon={<WarningIcon />}
          description={text("review_dialog_overage_warning")}
        />
      )}
      {checks.someWithoutFiles && (
        <Banner variant="alert" icon={<WarningIcon />} description={text("no_file_alert")} />
      )}
    </div>
  );
}
