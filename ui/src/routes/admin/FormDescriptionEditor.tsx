import {
  Button,
  Checkbox,
  Collapsible,
  Empty,
  Input,
  InputArea,
  Loader,
  Select,
  TagInput,
  Text,
} from "@cloudflare/kumo";
import {
  ArrowDownIcon,
  ArrowUpIcon,
  CaretRightIcon,
  ListPlusIcon,
  PlusIcon,
  TrashIcon,
} from "@phosphor-icons/react";
import { useForm } from "@tanstack/react-form";
import { useRef, useState } from "react";
import type { ReactNode } from "react";
import { generatePath, useNavigate, useParams } from "react-router";
import { useSWRConfig } from "swr";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import type { FormDescription } from "../../gen/rubykaigi/sponsor_app/form_description_pb.ts";
import { ProblemType } from "../../gen/rubykaigi/sponsor_app/problem_pb.ts";
import { fieldViolations, problemTypeOf } from "../../lib/errors.ts";
import type { FormErrors } from "../../lib/errors.ts";
import { erroredFields, errorsAt } from "../../lib/fieldErrors.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { toastManager } from "../../lib/toast.ts";
import { paths } from "../paths.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import {
  ErrorList,
  joined,
  SaveBar,
  SaveErrorBanner,
  Section,
  useFieldReveal,
} from "./FormParts.tsx";
import { SandboxedHtml } from "./SandboxedHtml.tsx";
import {
  BOOTH_REQUEST_LABELS,
  FIELD_LABELS,
  FORM_DESCRIPTION_LAYOUT,
  FORM_LOCALES,
  MARKDOWN_FIELDS,
  defaultLocale,
  emptyCondition,
  emptyFallbackOption,
  formValuesFrom,
  inputFrom,
  isBoothRequest,
  movedIndex,
  planChoices,
  withCollisions,
} from "./formDescriptionForm.ts";

// One page for new, show and edit: the HAML admin has all three, so each of its links lands here.
export default function FormDescriptionEditor() {
  const { slug = "", locale } = useParams();
  const conference = useRpc(AdminService.method.getConference, { conferenceSlug: slug });
  const current = useRpc(
    AdminService.method.getFormDescription,
    locale === undefined ? null : { conferenceSlug: slug, locale },
  );
  useDocumentTitle(
    locale === undefined ? "New form description" : `Edit form description (${locale})`,
    conference.data?.conference?.conference?.name ?? slug,
  );

  if (current.error !== undefined && current.data === undefined) throw current.error;
  if (conference.error !== undefined && conference.data === undefined) throw conference.error;
  if (conference.data === undefined || (locale !== undefined && current.data === undefined)) {
    return <Loader size="lg" />;
  }

  return (
    <Editor
      key={locale ?? ""}
      slug={slug}
      conferenceName={conference.data.conference?.conference?.name ?? slug}
      planNames={conference.data.plans.map((plan) => plan.name)}
      describedLocales={conference.data.formDescriptionLocales}
      saved={current.data?.formDescription}
    />
  );
}

function Editor({
  slug,
  conferenceName,
  planNames,
  describedLocales,
  saved: initiallySaved,
}: {
  slug: string;
  conferenceName: string;
  planNames: string[];
  describedLocales: string[];
  saved: FormDescription | undefined;
}) {
  const navigate = useNavigate();
  const { mutate } = useSWRConfig();
  const createFormDescription = useRpcMutation(AdminService.method.createFormDescription);
  const updateFormDescription = useRpcMutation(AdminService.method.updateFormDescription);
  // What the server last answered: the ref for the next save, the state for the previews and the
  // defaults, which must match each reset or useForm restores the values from before it.
  const lastSaved = useRef(initiallySaved);
  const [saved, setSaved] = useState(initiallySaved);
  const [newLocale] = useState(() => defaultLocale(describedLocales));
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();

  const form = useForm({
    defaultValues: formValuesFrom(saved, newLocale),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      const input = inputFrom(value);
      const locale = lastSaved.current?.locale;
      let result: FormDescription | undefined;
      try {
        const response =
          locale === undefined
            ? await createFormDescription.trigger({ conferenceSlug: slug, input })
            : await updateFormDescription.trigger({ conferenceSlug: slug, locale, input });
        result = response.formDescription;
      } catch (error) {
        setSaveError(error);
        rejection.reject(formApi, value, withCollisions(saveErrors(error), value.fallbackOptions));
        const [first] = erroredFields(formApi.state.fieldMeta, FORM_DESCRIPTION_LAYOUT);
        if (first !== undefined) reveal(first.path);
        return;
      }
      setSaveError(undefined);
      if (result === undefined) return;
      lastSaved.current = result;
      setSaved(result);
      formApi.reset(formValuesFrom(result));
      toastManager.add({
        variant: "success",
        title: `Saved the ${result.locale} form description`,
      });
      // Leaves a page whose locale moved before revalidating, which would answer not_found there.
      if (result.locale !== initiallySaved?.locale) {
        await navigate(generatePath(paths.formDescription, { slug, locale: result.locale }), {
          replace: true,
        });
      }
      await mutate(
        (key) =>
          isRpcKeyOf(key, AdminService.method.getConference) ||
          isRpcKeyOf(key, AdminService.method.getFormDescription),
      );
    },
  });

  return (
    <form
      ref={formRef}
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault();
        void rejection.submit(form);
      }}
    >
      <PageHeader
        crumbs={[{ label: conferenceName, href: generatePath(paths.conference, { slug }) }]}
        title={saved === undefined ? "New form description" : "Edit form description"}
        subtitle={saved?.locale}
      />

      <Section title="Texts">
        <form.Field name="locale">
          {(field) => (
            <div data-field={field.name}>
              <Select
                label={FIELD_LABELS.locale}
                description="The locale of the application form these texts are for."
                placeholder="Choose a locale"
                className="min-w-40"
                value={field.state.value === "" ? null : field.state.value}
                onValueChange={(value) => field.handleChange(value ?? "")}
                items={LOCALE_ITEMS}
                error={joined(field.state.meta.errors)}
              />
            </div>
          )}
        </form.Field>

        {MARKDOWN_FIELDS.map(({ name, label, html }) => (
          <div key={name} className={saved === undefined ? "" : "grid gap-3 md:grid-cols-2"}>
            <form.Field name={name}>
              {(field) => (
                <InputArea
                  label={label}
                  description="Markdown supported"
                  data-field={field.name}
                  autoResize
                  minRows={4}
                  maxRows={20}
                  value={field.state.value}
                  onValueChange={field.handleChange}
                  onBlur={field.handleBlur}
                  error={joined(field.state.meta.errors)}
                />
              )}
            </form.Field>
            {saved !== undefined && <Preview label={label} html={saved[html]} />}
          </div>
        ))}
      </Section>

      <Section title={FIELD_LABELS.fallbackOptions}>
        <Text variant="secondary">
          Alternatives an applicant picks in case the plan they applied for cannot be granted. An
          option is offered when any of its conditions matches, and always when it has none.
        </Text>
        <form.Subscribe selector={(state) => errorsAt(state.fieldMeta, "fallbackOptions")}>
          {(errors) => <ErrorList field="fallbackOptions" errors={errors} />}
        </form.Subscribe>

        <form.Field name="fallbackOptions" mode="array">
          {(options) => (
            <div className="flex flex-col gap-3">
              {options.state.value.length === 0 && (
                <Empty
                  size="sm"
                  title="No fallback options"
                  description="The form asks for none."
                />
              )}
              <ul className="divide-y divide-kumo-line border-y border-kumo-line">
                {options.state.value.map((_option, index) => (
                  <form.Subscribe
                    key={index}
                    selector={(state) =>
                      Object.entries(state.fieldMeta).some(
                        ([name, meta]) =>
                          (name === `fallbackOptions[${index}]` ||
                            name.startsWith(`fallbackOptions[${index}].`)) &&
                          meta?.errors.some((error) => typeof error === "string"),
                      )
                    }
                  >
                    {(hasErrors) => (
                      <OptionRow
                        forceOpen={hasErrors}
                        summary={
                          // The array field re-renders only when options are added or removed.
                          <form.Subscribe selector={(state) => state.values.fallbackOptions[index]}>
                            {(option) => (
                              <>
                                <span className="shrink-0 text-kumo-subtle">#{index + 1}</span>
                                <span className="shrink-0 font-mono text-[0.9em]">
                                  {option?.value}
                                </span>
                                <span className="truncate text-kumo-subtle">{option?.name}</span>
                              </>
                            )}
                          </form.Subscribe>
                        }
                        actions={
                          <>
                            <MoveButtons
                              index={index}
                              length={options.state.value.length}
                              onMove={(to) => options.moveValue(index, to)}
                            />
                            <Button
                              variant="ghost"
                              shape="square"
                              size="sm"
                              icon={TrashIcon}
                              aria-label={`Remove option ${index + 1}`}
                              onClick={() => options.removeValue(index)}
                            />
                          </>
                        }
                      >
                        <div className="flex flex-col gap-3 pb-4 pl-6">
                          <div className="grid gap-3 md:grid-cols-[1fr_2fr]">
                            <form.Field name={`fallbackOptions[${index}].value`}>
                              {(field) => (
                                <Input
                                  label={FIELD_LABELS.value}
                                  description="What the sponsorship records."
                                  className="font-mono"
                                  data-field={field.name}
                                  value={field.state.value}
                                  onChange={(event) => field.handleChange(event.target.value)}
                                  error={joined(field.state.meta.errors)}
                                />
                              )}
                            </form.Field>
                            <form.Field name={`fallbackOptions[${index}].name`}>
                              {(field) => (
                                <Input
                                  label={FIELD_LABELS.name}
                                  description="What the form shows."
                                  data-field={field.name}
                                  value={field.state.value}
                                  onChange={(event) => field.handleChange(event.target.value)}
                                  error={joined(field.state.meta.errors)}
                                />
                              )}
                            </form.Field>
                          </div>

                          <form.Field name={`fallbackOptions[${index}].conditions`} mode="array">
                            {(conditions) => (
                              <div className="flex flex-col gap-2">
                                <Text bold>{FIELD_LABELS.conditions}</Text>
                                <form.Subscribe
                                  selector={(state) =>
                                    errorsAt(
                                      state.fieldMeta,
                                      `fallbackOptions[${index}].conditions`,
                                    )
                                  }
                                >
                                  {(errors) => (
                                    <ErrorList
                                      field={`fallbackOptions[${index}].conditions`}
                                      errors={errors}
                                    />
                                  )}
                                </form.Subscribe>
                                {conditions.state.value.map((_condition, conditionIndex) => {
                                  const path =
                                    `fallbackOptions[${index}].conditions[${conditionIndex}]` as const;
                                  return (
                                    <div
                                      key={conditionIndex}
                                      className="flex flex-col gap-2 rounded-md border border-kumo-line p-3"
                                    >
                                      <div className="flex flex-wrap items-start gap-6">
                                        <form.Field name={`${path}.plans`}>
                                          {(field) => {
                                            const choices = planChoices(
                                              planNames,
                                              field.state.value,
                                            );
                                            return (
                                              <form.Subscribe
                                                selector={(state) =>
                                                  errorsAt(state.fieldMeta, `${path}.plans`, {
                                                    items: true,
                                                  })
                                                }
                                              >
                                                {(errors) => (
                                                  <div data-field={field.name}>
                                                    <Checkbox.Group
                                                      legend={FIELD_LABELS.plans}
                                                      description={PLANS_HELP}
                                                      value={field.state.value}
                                                      onValueChange={(checked) =>
                                                        field.handleChange(
                                                          choices.filter((name) =>
                                                            checked.includes(name),
                                                          ),
                                                        )
                                                      }
                                                      error={joined(errors)}
                                                    >
                                                      {choices.map((name) => (
                                                        <Checkbox.Item
                                                          key={name}
                                                          value={name}
                                                          label={
                                                            planNames.includes(name)
                                                              ? name
                                                              : `${name} (no such plan)`
                                                          }
                                                        />
                                                      ))}
                                                    </Checkbox.Group>
                                                  </div>
                                                )}
                                              </form.Subscribe>
                                            );
                                          }}
                                        </form.Field>
                                        <form.Field name={`${path}.boothRequest`}>
                                          {(field) => (
                                            <div data-field={field.name}>
                                              <Select
                                                label={FIELD_LABELS.boothRequest}
                                                className="min-w-40"
                                                value={field.state.value}
                                                onValueChange={(value) => {
                                                  if (isBoothRequest(value))
                                                    field.handleChange(value);
                                                }}
                                                items={BOOTH_REQUEST_LABELS}
                                                error={joined(field.state.meta.errors)}
                                              />
                                            </div>
                                          )}
                                        </form.Field>
                                        <Button
                                          variant="ghost"
                                          shape="square"
                                          size="sm"
                                          icon={TrashIcon}
                                          aria-label={`Remove condition ${conditionIndex + 1}`}
                                          onClick={() => conditions.removeValue(conditionIndex)}
                                        />
                                      </div>
                                      <form.Subscribe
                                        selector={(state) => errorsAt(state.fieldMeta, path)}
                                      >
                                        {(errors) => <ErrorList field={path} errors={errors} />}
                                      </form.Subscribe>
                                    </div>
                                  );
                                })}
                                <div>
                                  <Button
                                    variant="secondary"
                                    size="sm"
                                    icon={PlusIcon}
                                    onClick={() => conditions.pushValue(emptyCondition())}
                                  >
                                    Add condition
                                  </Button>
                                </div>
                              </div>
                            )}
                          </form.Field>

                          <form.Field name={`fallbackOptions[${index}].priorityHuman`}>
                            {(field) => (
                              <form.Subscribe
                                selector={(state) =>
                                  errorsAt(
                                    state.fieldMeta,
                                    `fallbackOptions[${index}].priorityHuman`,
                                    {
                                      items: true,
                                    },
                                  )
                                }
                              >
                                {(errors) => (
                                  <div data-field={field.name}>
                                    <TagInput
                                      label={FIELD_LABELS.priorityHuman}
                                      description='Plans after the one applied for: a plan name or {plan}, optionally followed by !booth or !no_booth, or "!withdraw".'
                                      placeholder="Gold"
                                      value={field.state.value}
                                      onValueChange={field.handleChange}
                                      error={joined(errors)}
                                    />
                                  </div>
                                )}
                              </form.Subscribe>
                            )}
                          </form.Field>
                        </div>
                      </OptionRow>
                    )}
                  </form.Subscribe>
                ))}
              </ul>
              <div>
                <Button
                  variant="secondary"
                  icon={ListPlusIcon}
                  onClick={() => options.pushValue(emptyFallbackOption())}
                >
                  Add option
                </Button>
              </div>
            </div>
          )}
        </form.Field>
      </Section>

      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          errored: erroredFields(state.fieldMeta, FORM_DESCRIPTION_LAYOUT),
          isSubmitting: state.isSubmitting,
          isDirty: state.isDirty,
        })}
      >
        {({ formError, errored, isSubmitting, isDirty }) => (
          <SaveBar
            isDirty={isDirty}
            banner={
              <SaveErrorBanner
                formError={formError}
                errored={errored}
                error={saveError}
                onShow={reveal}
              />
            }
          >
            <Button type="submit" variant="primary" loading={isSubmitting}>
              {saved === undefined ? "Create" : "Save"}
            </Button>
          </SaveBar>
        )}
      </form.Subscribe>
    </form>
  );
}

// Field violations go to their fields. A locale already described is the locale field's problem.
function saveErrors(error: unknown): FormErrors {
  const errors = fieldViolations(error, { prefix: "input." });
  if (problemTypeOf(error) === ProblemType.CONFLICT && errors.form !== undefined) {
    return { fields: { ...errors.fields, locale: errors.form } };
  }
  return errors;
}

const LOCALE_ITEMS = Object.fromEntries(FORM_LOCALES.map((locale) => [locale, locale]));

const PLANS_HELP = `Any of these. Leave all unchecked to match any plan, with ${FIELD_LABELS.boothRequest} set to ${BOOTH_REQUEST_LABELS.requested} or ${BOOTH_REQUEST_LABELS.not_requested}.`;

// One fallback option: a line of its value and name that opens to edit. A row with an error stays
// open, so the field to reveal exists.
function OptionRow({
  forceOpen,
  summary,
  actions,
  children,
}: {
  forceOpen: boolean;
  summary: ReactNode;
  actions: ReactNode;
  children: ReactNode;
}) {
  const [open, setOpen] = useState(false);
  return (
    <li>
      <Collapsible open={open || forceOpen} onOpenChange={setOpen}>
        <div className="flex items-center gap-2 py-1.5">
          <Collapsible.Trigger className="flex min-w-0 flex-1 items-center gap-2 rounded-md py-1 text-left text-sm hover:bg-kumo-tint">
            <CaretRightIcon
              aria-hidden
              className="shrink-0 transition-transform [[data-panel-open]_&]:rotate-90"
            />
            {summary}
          </Collapsible.Trigger>
          <span className="flex shrink-0 gap-1">{actions}</span>
        </div>
        <Collapsible.Panel>{children}</Collapsible.Panel>
      </Collapsible>
    </li>
  );
}

function MoveButtons({
  index,
  length,
  onMove,
}: {
  index: number;
  length: number;
  onMove: (to: number) => void;
}) {
  const up = movedIndex(index, -1, length);
  const down = movedIndex(index, 1, length);
  return (
    <>
      <Button
        variant="ghost"
        shape="square"
        size="sm"
        icon={ArrowUpIcon}
        aria-label={`Move option ${index + 1} up`}
        disabled={up === undefined}
        onClick={() => up !== undefined && onMove(up)}
      />
      <Button
        variant="ghost"
        shape="square"
        size="sm"
        icon={ArrowDownIcon}
        aria-label={`Move option ${index + 1} down`}
        disabled={down === undefined}
        onClick={() => down !== undefined && onMove(down)}
      />
    </>
  );
}

function Preview({ label, html }: { label: string; html: string }) {
  return (
    <div className="flex flex-col gap-1">
      <Text bold>Preview</Text>
      {html === "" ? (
        <Text variant="secondary">Empty</Text>
      ) : (
        <div className="rounded-md border border-kumo-line bg-kumo-base p-2">
          <SandboxedHtml html={html} title={`${label} preview`} />
        </div>
      )}
    </div>
  );
}
