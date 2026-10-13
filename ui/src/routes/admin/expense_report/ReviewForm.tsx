import { timestampDate } from "@bufbuild/protobuf/wkt";
import { InputArea, Text } from "@cloudflare/kumo";
import { CheckIcon, XIcon } from "@phosphor-icons/react";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import { AdminService } from "../../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { ExpenseReportReview_Action } from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type { ExpenseReport } from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { fieldViolations } from "../../../lib/errors.ts";
import { erroredFields } from "../../../lib/fieldErrors.ts";
import type { FieldLayout } from "../../../lib/fieldErrors.ts";
import { optionalFromInput } from "../../../lib/forms.ts";
import { useSaveRejection } from "../../../lib/rejection.ts";
import { useRpcMutation } from "../../../lib/rpc.ts";
import { toastManager } from "../../../lib/toast.ts";
import { ErrorList, joined, SaveErrorBanner, useFieldReveal } from "../FormParts.tsx";
import { ConfirmAction } from "./ConfirmAction.tsx";
import { useEditor } from "./EditorContext.ts";
import { verdictOf } from "./reportView.ts";

// Named after ExpenseReportReviewInput's JSON fields.
type ReviewValues = { action: "approve" | "reject"; comment: string };

const INITIAL: ReviewValues = { action: "approve", comment: "" };

const REVIEW_LAYOUT: FieldLayout = { labels: { comment: "Comment", action: "Verdict" } };

const VERDICT_ACTIONS = {
  approve: ExpenseReportReview_Action.APPROVE,
  reject: ExpenseReportReview_Action.REJECT,
} as const;

// A day without its year or time, which the report's own dates are never far from.
const dayFormat = new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric" });

// Approves or rejects the latest submission, or replaces the verdict already given. The server
// requires a comment on a rejection.
export function ReviewForm() {
  const { target, report, applyReport } = useEditor();
  const createReview = useRpcMutation(AdminService.method.createExpenseReportReview);
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  // Set when Reject is pressed without a comment, so no dialog asks about a save that cannot work.
  const [missingComment, setMissingComment] = useState(false);
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();
  const verdict = verdictOf(report);

  const form = useForm({
    defaultValues: INITIAL,
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      let result: ExpenseReport | undefined;
      try {
        const response = await createReview.trigger({
          ...target,
          input: {
            action: VERDICT_ACTIONS[value.action],
            comment: optionalFromInput(value.comment.trim()),
          },
        });
        result = response.report;
      } catch (error) {
        setSaveError(error);
        rejection.reject(formApi, value, fieldViolations(error, { prefix: "input." }));
        const [first] = erroredFields(formApi.state.fieldMeta, REVIEW_LAYOUT);
        if (first !== undefined) reveal(first.path);
        return;
      }
      setSaveError(undefined);
      toastManager.add({
        variant: "success",
        title:
          value.action === "approve"
            ? "Approved the expense report"
            : "Rejected the expense report",
      });
      applyReport(result);
      formApi.reset();
    },
  });

  async function submit(action: ReviewValues["action"]) {
    form.setFieldValue("action", action);
    await rejection.submit(form);
  }

  return (
    <form
      ref={formRef}
      noValidate
      className="flex w-full flex-col gap-2"
      onSubmit={(event) => {
        event.preventDefault();
      }}
    >
      {verdict !== undefined && (
        <div className="flex flex-col gap-0.5">
          <Text bold>
            {verdict.kind === "approved"
              ? `Approved ${verdict.at === undefined ? "" : dayFormat.format(timestampDate(verdict.at))}`.trim()
              : `Rejected: ${verdict.comment}`}
          </Text>
          <Text variant="secondary">Change the verdict</Text>
        </div>
      )}
      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          errored: erroredFields(state.fieldMeta, REVIEW_LAYOUT),
          actionErrors: state.fieldMeta.action?.errors ?? [],
        })}
      >
        {({ formError, errored, actionErrors }) => (
          <>
            <SaveErrorBanner
              formError={formError}
              errored={errored}
              error={saveError}
              onShow={reveal}
            />
            <div className="flex flex-wrap items-end gap-2" data-field="action">
              <form.Field name="comment">
                {(field) => (
                  <div className="min-w-48 flex-1">
                    <InputArea
                      aria-label="Comment (required to reject)"
                      data-field={field.name}
                      rows={1}
                      placeholder="Comment (required to reject)"
                      value={field.state.value}
                      onChange={(event) => {
                        setMissingComment(false);
                        field.handleChange(event.target.value);
                      }}
                      onBlur={field.handleBlur}
                      error={
                        joined(field.state.meta.errors) ??
                        (missingComment
                          ? "Write a comment for the sponsor to reject this report."
                          : undefined)
                      }
                    />
                  </div>
                )}
              </form.Field>
              <ConfirmAction
                label="Reject"
                icon={XIcon}
                variant="secondary-destructive"
                title="Reject this expense report?"
                description="The report goes back to the sponsor with the comment."
                confirmLabel="Reject"
                beforeOpen={() => {
                  const hasComment = form.getFieldValue("comment").trim() !== "";
                  setMissingComment(!hasComment);
                  return hasComment;
                }}
                onConfirm={() => submit("reject")}
              />
              <ConfirmAction
                label="Approve"
                icon={CheckIcon}
                variant="primary"
                confirmVariant="primary"
                title="Approve this expense report?"
                description="Its line items and files can no longer be changed."
                confirmLabel="Approve"
                onConfirm={() => submit("approve")}
              />
            </div>
            <ErrorList errors={actionErrors} />
          </>
        )}
      </form.Subscribe>
    </form>
  );
}
