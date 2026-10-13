import { InputArea } from "@cloudflare/kumo";
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
import { ConfirmButton } from "../ConfirmButton.tsx";
import { ErrorList, joined, SaveErrorBanner, Section, useFieldReveal } from "../FormParts.tsx";
import { useEditor } from "./EditorContext.ts";

// Named after ExpenseReportReviewInput's JSON fields.
type ReviewValues = { action: "approve" | "reject"; comment: string };

const INITIAL: ReviewValues = { action: "approve", comment: "" };

const REVIEW_LAYOUT: FieldLayout = { labels: { comment: "Comment", action: "Verdict" } };

const VERDICTS = {
  approve: {
    action: ExpenseReportReview_Action.APPROVE,
    label: "Approve",
    question: "Approve this expense report?",
    consequence: "Its line items and files can no longer be changed.",
    done: "Approved",
  },
  reject: {
    action: ExpenseReportReview_Action.REJECT,
    label: "Reject",
    question: "Reject this expense report?",
    consequence: "The report goes back to the sponsor with the comment.",
    done: "Rejected",
  },
} as const;

// Approves or rejects the latest submission. The server requires a comment on a rejection.
export function ReviewForm() {
  const { target, applyReport } = useEditor();
  const createReview = useRpcMutation(AdminService.method.createExpenseReportReview);
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();

  const form = useForm({
    defaultValues: INITIAL,
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      let result: ExpenseReport | undefined;
      try {
        const response = await createReview.trigger({
          ...target,
          input: {
            action: VERDICTS[value.action].action,
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
        title: `${VERDICTS[value.action].done} the expense report`,
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
      onSubmit={(event) => {
        event.preventDefault();
      }}
    >
      <Section title="Review">
        <form.Field name="comment">
          {(field) => (
            <InputArea
              label="Comment (required for rejection)"
              data-field={field.name}
              rows={3}
              placeholder="Feedback for the sponsor…"
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        <form.Subscribe
          selector={(state) => ({
            formError: state.errorMap.onChange,
            errored: erroredFields(state.fieldMeta, REVIEW_LAYOUT),
            actionErrors: state.fieldMeta.action?.errors ?? [],
          })}
        >
          {({ formError, errored, actionErrors }) => (
            <div className="flex flex-col gap-3">
              <SaveErrorBanner
                formError={formError}
                errored={errored}
                error={saveError}
                onShow={reveal}
              />
              <div className="flex flex-wrap gap-2" data-field="action">
                <ConfirmButton
                  label={VERDICTS.approve.label}
                  icon={CheckIcon}
                  variant="primary"
                  title={VERDICTS.approve.question}
                  description={VERDICTS.approve.consequence}
                  confirmLabel={VERDICTS.approve.label}
                  onConfirm={() => submit("approve")}
                />
                <ConfirmButton
                  label={VERDICTS.reject.label}
                  icon={XIcon}
                  title={VERDICTS.reject.question}
                  description={VERDICTS.reject.consequence}
                  confirmLabel={VERDICTS.reject.label}
                  onConfirm={() => submit("reject")}
                />
              </div>
              <ErrorList errors={actionErrors} />
            </div>
          )}
        </form.Subscribe>
      </Section>
    </form>
  );
}
