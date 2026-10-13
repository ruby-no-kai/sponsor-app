import { Button, Checkbox, Input, InputArea, Select, Text } from "@cloudflare/kumo";
import { TrashIcon, XIcon } from "@phosphor-icons/react";
import { useForm, useStore } from "@tanstack/react-form";
import { useEffect, useState } from "react";
import type { RefObject } from "react";
import type {
  ExpenseLineItem,
  ExpenseReport,
} from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { toastManager } from "../../lib/toast.ts";
import { ErrorList, joined, SaveErrorBanner, useFieldReveal } from "../admin/FormParts.tsx";
import { saveErrorMessages } from "./saveErrorMessages.ts";
import { addAmounts, formatAmountAt, formatRate } from "./amounts.ts";
import { ConfirmAction } from "./ConfirmAction.tsx";
import { useEditor } from "./EditorContext.ts";
import { UploadHint } from "./EditorParts.tsx";
import {
  fieldLabels,
  isLineItemChanged,
  lineItemInputFrom,
  lineItemLayout,
  lineItemValuesFrom,
  newLineItemInput,
  storedAmounts,
  taxModes,
} from "./lineItemForm.ts";
import type { TaxMode } from "./lineItemForm.ts";
import { fileName } from "./reportView.ts";
import { useAction } from "./useAction.ts";

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
  const { role, rpc, text, notify, report, rounding, readOnly, isMobile, applyReport, fileUrl } =
    useEditor();
  const { decimal, taxRates } = rounding;
  const updateLineItem = useAction(rpc.updateLineItem);
  const createLineItem = useAction(rpc.createLineItem);
  const deleteLineItem = useAction(rpc.deleteLineItem);
  const labels = fieldLabels(text);
  const layout = lineItemLayout(text);
  const taxModeItems = taxModes(text);
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
        const response = await updateLineItem.run(item.id, lineItemInputFrom(value, decimal));
        result = response.report;
      } catch (error) {
        setSaveError(error);
        rejection.reject(formApi, value, fieldViolations(error, { prefix: "input." }));
        const [first] = erroredFields(formApi.state.fieldMeta, layout);
        if (first !== undefined) reveal(first.path);
        return;
      }
      setSaveError(undefined);
      toastManager.add({ variant: "success", title: text("saved", { title: item.title }) });
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
        const saved = await updateLineItem.run(item.id, lineItemInputFrom(values, decimal));
        applyReport(saved.report);
      }
      const response = await createLineItem.run(
        newLineItemInput(text("new_item_title"), values.fileIds),
      );
      applyReport(response.report);
      if (response.lineItem !== undefined) onSelectItem(response.lineItem.id);
    } catch (error) {
      notify(error);
    }
  }

  async function handleDelete() {
    const changed = await deleteLineItem.run(item.id);
    dirtyRef.current = false;
    applyReport(changed);
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
      : [
          {
            label: text("rate_not_offered", { rate: formatRate(values.taxRate) }),
            value: values.taxRate,
          },
        ]),
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
            label={labels.title}
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
            label={labels.notes}
            data-field={field.name}
            rows={2}
            placeholder={text("notes_placeholder")}
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
              label={labels.taxMode}
              value={field.state.value}
              onValueChange={(value) => {
                const mode = taxModeItems.find((option) => option.value === value)?.value;
                if (mode !== undefined) changeTaxMode(mode);
              }}
              items={taxModeItems}
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
                label={labels.taxRate}
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
              label={values.taxMode === "include" ? text("amount_incl") : text("amount_excl")}
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
                label={labels.taxAmount}
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
        {text("total_incl_label")}:{" "}
        <span className="font-mono text-[0.9em] font-medium">
          {total === undefined ? "—" : formatAmountAt(total, decimal)}
        </span>
      </Text>

      <form.Field name="preliminal">
        {(field) => (
          <div className="flex flex-col gap-1" data-field={field.name}>
            <Checkbox
              label={text("preliminal_label")}
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
              {labels.fileIds}
            </Text>
            {attached.length === 0 ? (
              <Text variant="secondary" size="sm">
                {text("no_files_attached")}
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
                      {fileName(file, text)}
                    </button>
                    {!readOnly && (
                      <Button
                        variant="ghost"
                        size="sm"
                        shape="square"
                        icon={XIcon}
                        title={text("detach", { name: fileName(file, text) })}
                        aria-label={text("detach", { name: fileName(file, text) })}
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
              <UploadHint message="drop_or_upload" onUploadFiles={onUploadLinked}>
                {attachable.length > 0 && (
                  <Select
                    aria-label={text("link_existing")}
                    value=""
                    onValueChange={(value) => {
                      if (typeof value === "string" && value !== "") {
                        field.handleChange([...field.state.value, value]);
                      }
                    }}
                    items={[
                      { label: text("link_existing"), value: "" },
                      ...attachable.map((file) => ({
                        label: fileName(file, text),
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
            errored: erroredFields(state.fieldMeta, layout),
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
                messages={role === "sponsor" ? saveErrorMessages(text) : undefined}
              />
              <div className="flex flex-wrap items-center gap-2">
                <Button
                  type="submit"
                  variant="primary"
                  loading={isSubmitting}
                  disabled={!isChanged}
                >
                  {text("save")}
                </Button>
                <Button
                  variant="secondary"
                  loading={createLineItem.isRunning}
                  onClick={() => void handleAddSameFiles()}
                >
                  {text("duplicate_keep_files")}
                </Button>
              </div>
              <div className="flex border-t border-kumo-line pt-3">
                <ConfirmAction
                  label={text("delete")}
                  icon={TrashIcon}
                  title={text("confirm_delete_item")}
                  description={item.title}
                  confirmLabel={text("delete")}
                  cancelLabel={text("review_dialog_cancel")}
                  onError={notify}
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
