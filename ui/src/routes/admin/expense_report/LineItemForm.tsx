import { Button, Checkbox, Input, InputArea, Select, Text } from "@cloudflare/kumo";
import { TrashIcon, XIcon } from "@phosphor-icons/react";
import { useForm, useStore } from "@tanstack/react-form";
import { useEffect, useState } from "react";
import type { RefObject } from "react";
import { AdminService } from "../../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import type {
  ExpenseLineItem,
  ExpenseReport,
} from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { fieldViolations } from "../../../lib/errors.ts";
import { erroredFields } from "../../../lib/fieldErrors.ts";
import { useSaveRejection } from "../../../lib/rejection.ts";
import { useRpcMutation } from "../../../lib/rpc.ts";
import { notifyError, toastManager } from "../../../lib/toast.ts";
import { ConfirmAction } from "./ConfirmAction.tsx";
import { ErrorList, joined, SaveErrorBanner, useFieldReveal } from "../FormParts.tsx";
import { addAmounts, formatAmountAt, formatRate } from "./amounts.ts";
import { useEditor } from "./EditorContext.ts";
import { UploadHint } from "./EditorParts.tsx";
import {
  FIELD_LABELS,
  LINE_ITEM_LAYOUT,
  TAX_MODES,
  isLineItemChanged,
  lineItemInputFrom,
  lineItemValuesFrom,
  newLineItemInput,
  storedAmounts,
} from "./lineItemForm.ts";
import type { TaxMode } from "./lineItemForm.ts";
import { fileName } from "./reportView.ts";

// Edits the selected line item. The parent keys it by the stored item but its position, so a save
// or a change made elsewhere starts it afresh, and a reorder does not.
export function LineItemForm({
  item,
  dirtyRef,
  onSelectItem,
  onDeleted,
  onPreviewFile,
  onUploadLinked,
}: {
  item: ExpenseLineItem;
  // Whether the form holds changes not saved, for the editor to ask before leaving them.
  dirtyRef: RefObject<boolean>;
  onSelectItem: (id: string) => void;
  onDeleted: () => void;
  onPreviewFile: (id: string) => void;
  onUploadLinked: (files: File[]) => void;
}) {
  const { target, report, rounding, readOnly, isMobile, applyReport, fileUrl } = useEditor();
  const { decimal, taxRates } = rounding;
  const updateLineItem = useRpcMutation(AdminService.method.updateExpenseLineItem);
  const createLineItem = useRpcMutation(AdminService.method.createExpenseLineItem);
  const deleteLineItem = useRpcMutation(AdminService.method.deleteExpenseLineItem);
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();

  const form = useForm({
    defaultValues: lineItemValuesFrom(item, rounding),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      let result: ExpenseReport | undefined;
      try {
        const response = await updateLineItem.trigger({
          ...target,
          lineItemId: item.id,
          input: lineItemInputFrom(value, decimal),
        });
        result = response.report;
      } catch (error) {
        setSaveError(error);
        rejection.reject(formApi, value, fieldViolations(error, { prefix: "input." }));
        const [first] = erroredFields(formApi.state.fieldMeta, LINE_ITEM_LAYOUT);
        if (first !== undefined) reveal(first.path);
        return;
      }
      setSaveError(undefined);
      toastManager.add({ variant: "success", title: `Saved ${item.title}` });
      applyReport(result);
    },
  });

  const values = useStore(form.store, (state) => state.values);
  const isChanged = isLineItemChanged(values, item, decimal);
  useEffect(() => {
    dirtyRef.current = isChanged;
    return () => {
      dirtyRef.current = false;
    };
  }, [dirtyRef, isChanged]);

  async function handleAddSameFiles() {
    try {
      if (isChanged) {
        const saved = await updateLineItem.trigger({
          ...target,
          lineItemId: item.id,
          input: lineItemInputFrom(values, decimal),
        });
        applyReport(saved.report);
      }
      const response = await createLineItem.trigger({
        ...target,
        input: newLineItemInput("New expense", values.fileIds),
      });
      applyReport(response.report);
      if (response.lineItem !== undefined) onSelectItem(response.lineItem.id);
    } catch (error) {
      notifyError(error);
    }
  }

  async function handleDelete() {
    const response = await deleteLineItem.trigger({ ...target, lineItemId: item.id });
    dirtyRef.current = false;
    applyReport(response.report);
    onDeleted();
  }

  function changeTaxMode(mode: TaxMode) {
    const previous = form.getFieldValue("taxMode");
    form.setFieldValue("taxMode", mode);
    const hadRate = previous === "exclude" || previous === "include";
    if ((mode === "exclude" || mode === "include") && !hadRate) {
      form.setFieldValue("taxRate", taxRates[0] ?? "0.1");
    }
  }

  const stored = storedAmounts(values, decimal);
  const total = addAmounts(stored.amount, stored.taxAmount);
  const attached = values.fileIds.flatMap((id) => {
    const file = report.files.find((candidate) => candidate.id === id);
    return file === undefined ? [] : [file];
  });
  const attachable = report.files.filter((file) => !values.fileIds.includes(file.id));
  const rateItems = [
    ...taxRates.map((rate) => ({ label: formatRate(rate), value: rate })),
    ...(taxRates.includes(values.taxRate)
      ? []
      : [{ label: `${formatRate(values.taxRate)} (not offered)`, value: values.taxRate }]),
  ];

  return (
    <form
      ref={formRef}
      className="@container flex flex-col gap-4 px-4 py-3"
      noValidate
      onSubmit={(event) => {
        event.preventDefault();
        void rejection.submit(form);
      }}
    >
      <form.Field name="title">
        {(field) => (
          <Input
            label={FIELD_LABELS.title}
            data-field={field.name}
            value={field.state.value}
            onChange={(event) => field.handleChange(event.target.value)}
            onBlur={field.handleBlur}
            disabled={readOnly}
            error={joined(field.state.meta.errors)}
          />
        )}
      </form.Field>

      <form.Field name="notes">
        {(field) => (
          <InputArea
            label={FIELD_LABELS.notes}
            data-field={field.name}
            rows={2}
            placeholder="(optional)"
            value={field.state.value}
            onChange={(event) => field.handleChange(event.target.value)}
            onBlur={field.handleBlur}
            disabled={readOnly}
            error={joined(field.state.meta.errors)}
          />
        )}
      </form.Field>

      <form.Field name="taxMode">
        {(field) => (
          <div data-field={field.name}>
            <Select
              label={FIELD_LABELS.taxMode}
              value={field.state.value}
              onValueChange={(value) => {
                const mode = TAX_MODES.find((option) => option.value === value)?.value;
                if (mode !== undefined) changeTaxMode(mode);
              }}
              items={TAX_MODES}
              disabled={readOnly}
            />
          </div>
        )}
      </form.Field>

      {(values.taxMode === "exclude" || values.taxMode === "include") && (
        <form.Field name="taxRate">
          {(field) => (
            <div data-field={field.name}>
              <Select
                label={FIELD_LABELS.taxRate}
                value={field.state.value}
                onValueChange={(value) => field.handleChange(String(value ?? ""))}
                items={rateItems}
                disabled={readOnly}
                error={joined(field.state.meta.errors)}
              />
            </div>
          )}
        </form.Field>
      )}

      <div className="grid grid-cols-1 gap-4 @md:grid-cols-2 [&>*]:min-w-0">
        <form.Field name="amount">
          {(field) => (
            <Input
              label={values.taxMode === "include" ? "Amount (incl. tax)" : "Amount (excl. tax)"}
              data-field={field.name}
              inputMode="decimal"
              className="font-mono"
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              disabled={readOnly}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        {values.taxMode === "manual" && (
          <form.Field name="taxAmount">
            {(field) => (
              <Input
                label={FIELD_LABELS.taxAmount}
                data-field={field.name}
                inputMode="decimal"
                className="font-mono"
                value={field.state.value}
                onChange={(event) => field.handleChange(event.target.value)}
                onBlur={field.handleBlur}
                disabled={readOnly}
                error={joined(field.state.meta.errors)}
              />
            )}
          </form.Field>
        )}
      </div>
      <form.Subscribe selector={(state) => state.fieldMeta.taxAmount?.errors ?? []}>
        {(errors) => values.taxMode !== "manual" && <ErrorList field="taxAmount" errors={errors} />}
      </form.Subscribe>

      <Text variant="secondary">
        Total (incl. tax):{" "}
        <span className="font-mono text-[0.9em] font-medium">
          {total === undefined ? "—" : formatAmountAt(total, decimal)}
        </span>
      </Text>

      <form.Field name="preliminal">
        {(field) => (
          <div className="flex flex-col gap-1" data-field={field.name}>
            <Checkbox
              label="Preliminal (planned budget, not finalized)"
              checked={field.state.value}
              onCheckedChange={(checked) => field.handleChange(checked)}
              disabled={readOnly}
            />
            <ErrorList errors={field.state.meta.errors} />
          </div>
        )}
      </form.Field>

      <form.Field name="fileIds">
        {(field) => (
          <div className="flex flex-col gap-2" data-field={field.name}>
            <Text bold size="sm">
              {FIELD_LABELS.fileIds}
            </Text>
            {attached.length === 0 ? (
              <Text variant="secondary" size="sm">
                No files attached
              </Text>
            ) : (
              <ul className="flex flex-col gap-1">
                {attached.map((file) => (
                  <li key={file.id.toString()} className="flex items-center justify-between gap-2">
                    <button
                      type="button"
                      className="truncate text-left text-sm text-kumo-link underline"
                      onClick={() =>
                        isMobile
                          ? window.open(fileUrl(file.id), "_blank", "noopener,noreferrer")
                          : onPreviewFile(file.id)
                      }
                    >
                      {fileName(file)}
                    </button>
                    {!readOnly && (
                      <Button
                        variant="ghost"
                        size="sm"
                        shape="square"
                        icon={XIcon}
                        title={`Detach ${fileName(file)}`}
                        aria-label={`Detach ${fileName(file)}`}
                        onClick={() =>
                          field.handleChange(field.state.value.filter((id) => id !== file.id))
                        }
                      />
                    )}
                  </li>
                ))}
              </ul>
            )}
            <ErrorList errors={field.state.meta.errors} />
            {!readOnly && (
              <UploadHint prompt="Drop files here to attach, or" onUploadFiles={onUploadLinked}>
                {attachable.length > 0 && (
                  <Select
                    aria-label="Link an existing file"
                    value=""
                    onValueChange={(value) => {
                      if (typeof value === "string" && value !== "") {
                        field.handleChange([...field.state.value, value]);
                      }
                    }}
                    items={[
                      { label: "Link an existing file…", value: "" },
                      ...attachable.map((file) => ({
                        label: fileName(file),
                        value: file.id,
                      })),
                    ]}
                  />
                )}
              </UploadHint>
            )}
          </div>
        )}
      </form.Field>

      {!readOnly && (
        <form.Subscribe
          selector={(state) => ({
            formError: state.errorMap.onChange,
            errored: erroredFields(state.fieldMeta, LINE_ITEM_LAYOUT),
            isSubmitting: state.isSubmitting,
          })}
        >
          {({ formError, errored, isSubmitting }) => (
            <div className="flex flex-col gap-3">
              <SaveErrorBanner
                formError={formError}
                errored={errored}
                error={saveError}
                onShow={reveal}
              />
              <div className="flex flex-wrap items-center gap-2">
                <Button
                  type="submit"
                  variant="primary"
                  loading={isSubmitting}
                  disabled={!isChanged}
                >
                  Save
                </Button>
                <Button
                  variant="secondary"
                  loading={createLineItem.isMutating}
                  onClick={() => void handleAddSameFiles()}
                >
                  Duplicate line, keep files
                </Button>
              </div>
              <div className="flex border-t border-kumo-line pt-3">
                <ConfirmAction
                  label="Delete"
                  icon={TrashIcon}
                  title="Delete this line item?"
                  description={`${item.title} is removed from the report. Its files stay.`}
                  confirmLabel="Delete"
                  onConfirm={handleDelete}
                />
              </div>
            </div>
          )}
        </form.Subscribe>
      )}
    </form>
  );
}
