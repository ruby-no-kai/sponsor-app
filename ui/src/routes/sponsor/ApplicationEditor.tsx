import {
  Badge,
  Banner,
  Button,
  Checkbox,
  Input,
  InputArea,
  LinkButton,
  Radio,
  Select,
  TableOfContents,
  Text,
  useTableOfContentsActiveId,
} from "@cloudflare/kumo";
import { Code, ConnectError } from "@connectrpc/connect";
import { WarningIcon } from "@phosphor-icons/react";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import type { ReactNode } from "react";
import { useSWRConfig } from "swr";
import type { Conference } from "../../gen/rubykaigi/sponsor_app/conference_pb.ts";
import type { FormDescription } from "../../gen/rubykaigi/sponsor_app/form_description_pb.ts";
import type {
  ApplicationPlan,
  SponsorshipApplication,
} from "../../gen/rubykaigi/sponsor_app/sponsor_applications_pb.ts";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { problemDetailsOf, requestIdOf } from "../../lib/errors.ts";
import type { FormErrors } from "../../lib/errors.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import type { FieldError } from "../../lib/fieldErrors.ts";
import { ErrorList, Section, StickySaveBar, joined, useFieldReveal } from "../../lib/FormParts.tsx";
import type { FieldOf } from "../../lib/FormParts.tsx";
import { idFromInput, idToInput } from "../../lib/forms.ts";
import { useT } from "../../lib/i18n.tsx";
import type { Translate } from "../../lib/i18n.tsx";
import { useGoTo } from "../../lib/navigation.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { callRpc, isRpcKeyOf, useRpcMutation } from "../../lib/rpc.ts";
import { SandboxedHtml } from "../../lib/SandboxedHtml.tsx";
import { toastManager } from "../../lib/toast.ts";
import { UploadOnce, uploadFile } from "../../lib/upload.ts";
import type { Progress } from "../../lib/upload.ts";
import {
  APPLICATION_LAYOUT,
  OTHER_PLAN,
  boothApplies,
  fallbackSelectionOf,
  fieldLabelKeys,
  initialValues,
  inputFrom,
  isPlanSelectable,
  isZipFile,
  looksNonEnglish,
  offeredFallbackOptions,
  offersOtherPlan,
  priorityItems,
  saveErrors,
  selectedPlan,
  ticketCounts,
  uploadFailure,
  validateApplication,
} from "./applicationForm.ts";
import type { ApplicationValues, AssetChoice, ValidationMessages } from "./applicationForm.ts";
import { AssetFileField } from "./AssetFileField.tsx";
import type { CurrentAssetFile } from "./AssetFileField.tsx";
import { dashboardPath } from "./shellRedirects.ts";

// A new application carries the codes of the link it was opened from. An application being
// edited keeps its plan once accepted, and turns read-only once amendments close.
export type EditorMode =
  | { kind: "new"; inviteCode: string; affiliation: string }
  | { kind: "edit"; savedPlanId: bigint | undefined; accepted: boolean; readOnly: boolean };

// The application form, for applying and for amending an application, as the HAML form is.
export function ApplicationEditor({
  slug,
  conference,
  plans,
  description,
  application,
  currentAsset,
  mode,
  intro,
}: {
  slug: string;
  conference: Conference;
  plans: ApplicationPlan[];
  description: FormDescription;
  // The answers the form starts from: the saved ones, or those copied from another application.
  application: SponsorshipApplication | undefined;
  currentAsset: CurrentAssetFile | undefined;
  mode: EditorMode;
  // Shown under the form's introduction, such as the choice of an application to copy.
  intro?: ReactNode;
}) {
  const t = useT();
  const goTo = useGoTo();
  const { mutate } = useSWRConfig();
  const createSponsorship = useRpcMutation(SponsorService.method.createSponsorship);
  const updateSponsorship = useRpcMutation(SponsorService.method.updateSponsorship);
  const creating = mode.kind === "new";
  const editing = mode.kind === "edit" ? mode : undefined;
  const readOnly = editing?.readOnly ?? false;
  const savedPlanId = editing?.savedPlanId;
  const options = description.fallbackOptions;

  const [initial] = useState(() =>
    initialValues(application, { saved: !creating, plans, fallbackOptions: options }),
  );
  const [uploads] = useState(() => new UploadOnce());
  const [progress, setProgress] = useState<Progress>();
  // The error of the last save, for its request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();

  const startUpload = (file: File) => {
    const contentType = file.type === "" ? undefined : file.type;
    // The application's own logo is replaced in place. Any other upload makes a new file.
    if (editing !== undefined && initial.assetFileId.kind === "existing") {
      return callRpc(SponsorService.method.initiateSponsorshipAssetUpdate, {
        conferenceSlug: slug,
        assetFileId: idFromInput(initial.assetFileId.id),
        contentType,
      });
    }
    return callRpc(SponsorService.method.createSponsorshipAssetUpload, {
      conferenceSlug: slug,
      inviteCode: mode.kind === "new" ? mode.inviteCode : "",
      contentType,
    });
  };

  const assetFileIdOf = async (choice: AssetChoice): Promise<bigint | undefined> => {
    switch (choice.kind) {
      case "none":
        return undefined;
      case "existing":
        return idFromInput(choice.id);
      case "file": {
        const { file } = choice;
        return uploads.ensure(file, () =>
          uploadFile(
            file,
            {
              start: async () => (await startUpload(file)).upload,
              complete: (assetFileId, versionId, extension) =>
                callRpc(SponsorService.method.completeSponsorshipAssetUpload, {
                  conferenceSlug: slug,
                  assetFileId,
                  versionId,
                  extension,
                }),
            },
            { onProgress: setProgress },
          ),
        );
      }
      default:
        return choice satisfies never;
    }
  };

  // Uploads the logo when one is chosen, then saves. Returns the errors that kept it unsaved, and
  // whether the logo chosen is to be dropped, as it failed to upload.
  const save = async (values: ApplicationValues): Promise<SaveResult> => {
    setSaveError(undefined);
    const fallbackOffered =
      offeredFallbackOptions(options, fallbackSelectionOf(values, plans)).length > 0;
    const invalid = validateApplication(
      values,
      { creating, fallbackOffered },
      validationMessages(t),
    );
    if (invalid !== undefined) return { errors: invalid };

    let assetFileId: bigint | undefined;
    try {
      setProgress(values.assetFileId.kind === "file" ? { loaded: 0, total: 0 } : undefined);
      assetFileId = await assetFileIdOf(values.assetFileId);
    } catch (error) {
      setSaveError(error);
      const file = values.assetFileId.kind === "file" ? values.assetFileId.file.name : "";
      return { errors: uploadErrors(t, error, file), dropFile: true };
    } finally {
      setProgress(undefined);
    }

    try {
      const input = inputFrom(values, assetFileId);
      if (mode.kind === "new") {
        await createSponsorship.trigger({
          conferenceSlug: slug,
          inviteCode: mode.inviteCode,
          affiliation: mode.affiliation,
          input,
          policyAgreement: values.policyAgreement,
        });
      } else {
        await updateSponsorship.trigger({ conferenceSlug: slug, input });
      }
    } catch (error) {
      setSaveError(error);
      const connectError = ConnectError.from(error);
      if (connectError.code === Code.InvalidArgument) return { errors: saveErrors(error) };
      return {
        errors: {
          form: problemDetailsOf(error)?.title || t("sponsor_ui.shell.error.title"),
          fields: {},
        },
      };
    }
    return { errors: undefined };
  };

  const finish = async () => {
    toastManager.add({
      variant: "success",
      title: creating ? t("sponsorships.create.notice") : t("sponsor_ui.applications.updated"),
    });
    await Promise.all([
      // The dashboard tells from the viewer whether the browser sponsors the conference.
      mutate(
        (key) =>
          isRpcKeyOf(key, SponsorService.method.getViewer) ||
          isRpcKeyOf(key, SponsorService.method.getSponsorship) ||
          isRpcKeyOf(key, SponsorService.method.getSponsorshipApplication),
      ),
      // Dropped rather than fetched again, as the answer would send this page to the dashboard
      // on its own.
      mutate((key) => isRpcKeyOf(key, SponsorService.method.getApplicationForm), undefined, {
        revalidate: false,
      }),
    ]);
    goTo(dashboardPath(slug));
  };

  const form = useForm({
    defaultValues: initial,
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      const { errors, dropFile } = await save(value);
      if (errors === undefined) {
        await finish();
        return;
      }
      // A file that failed to upload would be sent again by the next save.
      if (dropFile === true) formApi.setFieldValue("assetFileId", initial.assetFileId);
      rejection.reject(formApi, value, errors);
      const [first] = erroredFields(formApi.state.fieldMeta, APPLICATION_LAYOUT);
      if (first !== undefined) reveal(first.path);
    },
  });

  const textInput = (
    field: FieldOf<string>,
    label: string,
    {
      type = "text",
      description,
      placeholder,
    }: { type?: string; description?: ReactNode; placeholder?: string } = {},
  ) => (
    <Input
      label={label}
      description={description}
      placeholder={placeholder}
      type={type}
      data-field={field.name}
      value={field.state.value}
      onChange={(event) => field.handleChange(event.target.value)}
      onBlur={field.handleBlur}
      error={joined(field.state.meta.errors)}
    />
  );

  const textArea = (field: FieldOf<string>, label: string, description?: ReactNode) => (
    <InputArea
      label={label}
      description={description}
      data-field={field.name}
      autoResize
      minRows={3}
      maxRows={16}
      value={field.state.value}
      onValueChange={field.handleChange}
      onBlur={field.handleBlur}
      error={joined(field.state.meta.errors)}
    />
  );

  const checkbox = (
    field: FieldOf<boolean>,
    label: ReactNode,
    {
      disabled = false,
      onChange,
    }: { disabled?: boolean; onChange?: (checked: boolean) => void } = {},
  ) => (
    <div className="flex flex-col gap-1" data-field={field.name}>
      <Checkbox
        label={label}
        checked={field.state.value}
        disabled={disabled}
        onCheckedChange={(checked) => {
          field.handleChange(checked === true);
          onChange?.(checked === true);
        }}
      />
      <ErrorList errors={field.state.meta.errors} />
    </div>
  );

  const contactFields = (prefix: "contact" | "alternateBillingContact") => {
    const label = (name: string) => t(`activerecord.attributes.contact.${name}`);
    const optional = t("sponsorships.form.optional");
    return (
      <div className="grid gap-3 md:grid-cols-2">
        <form.Field name={`${prefix}.email`}>
          {(field) =>
            textInput(field, label("email"), {
              type: "email",
              description: prefix === "contact" ? t("sponsorships.form.email_help") : undefined,
            })
          }
        </form.Field>
        {prefix === "contact" && (
          <form.Field name="contact.emailCc">
            {(field) =>
              textInput(field, label("email_cc"), {
                description: t("sponsorships.form.email_cc_help"),
                placeholder: optional,
              })
            }
          </form.Field>
        )}
        <form.Field name={`${prefix}.address`}>
          {(field) => textInput(field, label("address"))}
        </form.Field>
        <form.Field name={`${prefix}.organization`}>
          {(field) => textInput(field, label("organization"))}
        </form.Field>
        <form.Field name={`${prefix}.unit`}>
          {(field) => textInput(field, label("unit"), { placeholder: optional })}
        </form.Field>
        <form.Field name={`${prefix}.name`}>
          {(field) => textInput(field, label("name"))}
        </form.Field>
      </div>
    );
  };

  const resetFallbackOption = () => form.setFieldValue("fallbackOption", "");

  const sections = [
    "contact",
    "billing",
    "plan",
    ...(conference.boothsOffered ? ["booth"] : []),
    "company",
    "logo",
    ...(conference.additionalAttendeesRegistrationOpen ? ["tickets"] : []),
    "note",
    "policies",
  ];

  return (
    <form
      ref={formRef}
      noValidate
      className="flex flex-col gap-4"
      onSubmit={(event) => {
        event.preventDefault();
        void rejection.submit(form);
      }}
    >
      <Text variant="heading" size="lg" as="h1">
        {t("sponsorships.form.header", { name: conference.name })}
      </Text>
      <HelpHtml html={description.headHtml} title={conference.name} />
      {intro}

      <div className="flex flex-col gap-4 lg:grid lg:grid-cols-[12rem_minmax(0,1fr)] lg:items-start lg:gap-8">
        <SectionList sections={sections} />
        <fieldset disabled={readOnly} className="flex min-w-0 flex-col gap-4">
          <Section id={sectionId("contact")} title={t("sponsor_ui.applications.sections.contact")}>
            {contactFields("contact")}
          </Section>

          <Section id={sectionId("billing")} title={t("sponsor_ui.applications.sections.billing")}>
            <Text>{t("sponsorships.form.billing_help")}</Text>
            <form.Field name="specifiesBillingContact">
              {(field) => checkbox(field, t("sponsorships.form.specify_alternate_billing_contact"))}
            </form.Field>
            <form.Subscribe selector={(state) => state.values.specifiesBillingContact}>
              {(specifies) => specifies && contactFields("alternateBillingContact")}
            </form.Subscribe>
            <form.Field name="billingRequest">
              {(field) =>
                textArea(
                  field,
                  t("activerecord.attributes.sponsorship/billing_request.body"),
                  t("sponsorships.form.billing_request_help"),
                )
              }
            </form.Field>
          </Section>

          <Section id={sectionId("plan")} title={t("sponsor_ui.applications.sections.plan")}>
            <HelpHtml html={description.planHelpHtml} title={t("sponsorships.form.plan")} />
            <form.Field name="planId">
              {(field) => (
                <div data-field={field.name}>
                  <Radio.Group
                    legend={t("sponsorships.form.plans")}
                    value={field.state.value}
                    disabled={editing?.accepted ?? false}
                    onValueChange={(value) => {
                      field.handleChange(String(value));
                      if (!boothApplies(conference, selectedPlan(plans, String(value)))) {
                        form.setFieldValue("boothRequested", false);
                      }
                      resetFallbackOption();
                    }}
                    error={joined(field.state.meta.errors)}
                  >
                    {plans.map((plan) => (
                      <Radio.Item
                        key={plan.id.toString()}
                        value={idToInput(plan.id)}
                        disabled={!isPlanSelectable(plan, savedPlanId)}
                        label={<PlanLabel plan={plan} />}
                      />
                    ))}
                    {offersOtherPlan(conference, { saved: !creating, savedPlanId }) && (
                      <Radio.Item
                        value={OTHER_PLAN}
                        label={t("sponsor_ui.applications.other_plan")}
                      />
                    )}
                  </Radio.Group>
                </div>
              )}
            </form.Field>
            <form.Field name="customizationRequest">
              {(field) =>
                textArea(field, t("activerecord.attributes.sponsorship/customization_request.body"))
              }
            </form.Field>
          </Section>

          {conference.boothsOffered && (
            <Section id={sectionId("booth")} title={t("sponsor_ui.applications.sections.booth")}>
              <HelpHtml html={description.boothHelpHtml} title={t("sponsorships.form.booth")} />
              <form.Subscribe selector={(state) => state.values.planId}>
                {(planId) => {
                  const applies = boothApplies(conference, selectedPlan(plans, planId));
                  return (
                    <>
                      <form.Field name="boothRequested">
                        {(field) =>
                          checkbox(field, t("helpers.label.sponsorship.booth_requested"), {
                            disabled: !applies,
                            onChange: resetFallbackOption,
                          })
                        }
                      </form.Field>
                      {!applies && (
                        <Text variant="secondary" size="sm">
                          {t("sponsorships.form.booth_uneligible_plan_selected", {
                            plans: plans
                              .filter((plan) => plan.boothEligible)
                              .map((plan) => plan.name)
                              .join(", "),
                          })}
                        </Text>
                      )}
                    </>
                  );
                }}
              </form.Subscribe>
            </Section>
          )}

          {options.length > 0 && (
            <form.Subscribe
              selector={(state) => ({
                planId: state.values.planId,
                boothRequested: state.values.boothRequested,
              })}
            >
              {(selection) => {
                const offered = offeredFallbackOptions(
                  options,
                  fallbackSelectionOf(selection, plans),
                );
                if (offered.length === 0) return null;
                const plan = selectedPlan(plans, selection.planId);
                return (
                  <Section title={t("sponsor_ui.applications.sections.fallback_option")}>
                    <Text>{t("sponsorships.form.fallback_option_help")}</Text>
                    <form.Field name="fallbackOption">
                      {(field) => {
                        const chosen = offered.find(({ value }) => value === field.state.value);
                        return (
                          <div className="flex flex-col gap-3" data-field={field.name}>
                            <Select
                              label={t("activerecord.attributes.sponsorship.fallback_option")}
                              className="min-w-60"
                              placeholder={t("sponsorships.form.fallback_option_blank")}
                              value={chosen === undefined ? null : chosen.value}
                              onValueChange={(value) => field.handleChange(String(value ?? ""))}
                              items={offered.map(({ name, value }) => ({ label: name, value }))}
                              error={joined(field.state.meta.errors)}
                            />
                            {chosen !== undefined && (
                              <div className="flex flex-col gap-2 rounded-md border border-kumo-line p-3">
                                <Text variant="heading" as="h3">
                                  {t("sponsorships.form.fallback_priority.header")}
                                </Text>
                                <Text>{t("sponsorships.form.fallback_priority.help")}</Text>
                                <ol className="list-inside list-decimal">
                                  {priorityItems(
                                    chosen,
                                    {
                                      planName: plan?.name,
                                      boothApplies: boothApplies(conference, plan),
                                      boothRequested: selection.boothRequested,
                                    },
                                    {
                                      withdraw: t(
                                        "sponsorships.form.fallback_option_priority.withdraw",
                                      ),
                                      booth: t("sponsorships.form.fallback_option_priority.booth"),
                                      noBooth: t(
                                        "sponsorships.form.fallback_option_priority.no_booth",
                                      ),
                                    },
                                  ).map((item, index) => (
                                    <li key={index}>{item}</li>
                                  ))}
                                </ol>
                              </div>
                            )}
                          </div>
                        );
                      }}
                    </form.Field>
                  </Section>
                );
              }}
            </form.Subscribe>
          )}

          <Section id={sectionId("company")} title={t("sponsor_ui.applications.sections.company")}>
            <Text>
              <span className="whitespace-pre-line">{t("sponsorships.form.information_help")}</span>
            </Text>
            <form.Field name="name">
              {(field) => textInput(field, t("activerecord.attributes.sponsorship.name"))}
            </form.Field>
            <form.Field name="url">
              {(field) =>
                textInput(field, t("activerecord.attributes.sponsorship.url"), {
                  type: "url",
                  placeholder: "https://...",
                })
              }
            </form.Field>
            <form.Subscribe selector={(state) => state.values.planId}>
              {(planId) => {
                const plan = selectedPlan(plans, planId);
                return (
                  <form.Field name="profile">
                    {(field) =>
                      textArea(
                        field,
                        t("activerecord.attributes.sponsorship.profile"),
                        plan === undefined
                          ? undefined
                          : t("sponsorships.form.plan_explanation.words_limit", {
                              count: plan.wordsLimit,
                            }),
                      )
                    }
                  </form.Field>
                );
              }}
            </form.Subscribe>
            <form.Subscribe
              selector={(state) => looksNonEnglish(state.values.name, state.values.profile)}
            >
              {(nonEnglish) =>
                nonEnglish && (
                  <Banner
                    variant="alert"
                    icon={<WarningIcon />}
                    title={t("sponsorships.form.warnings.english.header")}
                    description={
                      <div className="flex flex-col gap-2">
                        <Text>{t("sponsorships.form.warnings.english.body1")}</Text>
                        <Text>{t("sponsorships.form.warnings.english.body2")}</Text>
                        <form.Field name="englishAcknowledged">
                          {(field) =>
                            checkbox(field, t("sponsorships.form.warnings.english.acknowledge"))
                          }
                        </form.Field>
                      </div>
                    }
                  />
                )
              }
            </form.Subscribe>
          </Section>

          <Section id={sectionId("logo")} title={t("sponsor_ui.applications.sections.logo")}>
            <Text>{t("sponsorships.form.logo_help")}</Text>
            <Text>{t("sponsorships.form.logo_zip_help")}</Text>
            <form.Field name="assetFileId">
              {(field) => (
                <AssetFileField
                  field={field}
                  initial={initial.assetFileId}
                  current={currentAsset}
                  progress={progress}
                />
              )}
            </form.Field>
            <form.Subscribe
              selector={(state) =>
                state.values.assetFileId.kind === "file" && isZipFile(state.values.assetFileId.file)
              }
            >
              {(zip) =>
                zip && (
                  <Banner
                    variant="alert"
                    icon={<WarningIcon />}
                    title={t("sponsorships.form.warnings.zip_asset.header")}
                    description={
                      <div className="flex flex-col gap-2">
                        <ul className="list-inside list-disc">
                          {[0, 1, 2, 3].map((item) => (
                            <li key={item}>
                              {t(`sponsorships.form.warnings.zip_asset.item${item}`)}
                            </li>
                          ))}
                        </ul>
                        <form.Field name="zipAcknowledged">
                          {(field) =>
                            checkbox(field, t("sponsorships.form.warnings.zip_asset.acknowledge"))
                          }
                        </form.Field>
                      </div>
                    }
                  />
                )
              }
            </form.Subscribe>
          </Section>

          {conference.additionalAttendeesRegistrationOpen && (
            <Section
              id={sectionId("tickets")}
              title={t("sponsor_ui.applications.sections.tickets")}
            >
              <HelpHtml html={description.ticketHelpHtml} title={t("sponsorships.form.tickets")} />
              <form.Subscribe
                selector={(state) => ({
                  planId: state.values.planId,
                  additional: state.values.numberOfAdditionalAttendees,
                })}
              >
                {({ planId, additional }) => {
                  const { included, total } = ticketCounts(selectedPlan(plans, planId), additional);
                  return (
                    <dl className="grid max-w-md grid-cols-[1fr_auto] items-center gap-x-4 gap-y-2">
                      <dt>{t("sponsorships.form.tickets_included_in_plan")}</dt>
                      <dd className="text-right">{included}</dd>
                      <dt>{t("sponsorships.form.tickets_additionally_request")}</dt>
                      <dd>
                        <form.Field name="numberOfAdditionalAttendees">
                          {(field) => (
                            <div className="flex w-28 flex-col gap-1" data-field={field.name}>
                              <Input
                                aria-label={t("sponsorships.form.tickets_additionally_request")}
                                type="number"
                                min={0}
                                inputMode="numeric"
                                className="text-right"
                                value={field.state.value}
                                onChange={(event) => field.handleChange(event.target.value)}
                                onBlur={field.handleBlur}
                              />
                            </div>
                          )}
                        </form.Field>
                      </dd>
                      <dt>{t("sponsorships.form.tickets_total")}</dt>
                      <dd className="text-right font-semibold">{total}</dd>
                    </dl>
                  );
                }}
              </form.Subscribe>
              <form.Subscribe
                selector={(state) => state.fieldMeta.numberOfAdditionalAttendees?.errors ?? []}
              >
                {(errors) => <ErrorList errors={errors} />}
              </form.Subscribe>
            </Section>
          )}

          <Section id={sectionId("note")} title={t("sponsor_ui.applications.sections.note")}>
            <Text>{t("sponsorships.form.others_help")}</Text>
            <form.Field name="note">
              {(field) => textArea(field, t("activerecord.attributes.sponsorship/note.body"))}
            </form.Field>
          </Section>

          <Section
            id={sectionId("policies")}
            title={t("sponsor_ui.applications.sections.policies")}
          >
            <HelpHtml html={description.policyHelpHtml} title={t("sponsorships.form.policies")} />
            {creating && (
              <form.Field name="policyAgreement">
                {(field) =>
                  checkbox(field, t("activerecord.attributes.sponsorship.policy_agreement"))
                }
              </form.Field>
            )}
          </Section>
        </fieldset>
      </div>

      {!readOnly && (
        <form.Subscribe
          selector={(state) => ({
            planId: state.values.planId,
            formError: state.errorMap.onChange,
            errored: erroredFields(state.fieldMeta, APPLICATION_LAYOUT),
            isSubmitting: state.isSubmitting,
          })}
        >
          {({ planId, formError, errored, isSubmitting }) => {
            const plan = selectedPlan(plans, planId);
            return (
              <StickySaveBar
                banner={
                  <>
                    <SaveErrorBanner
                      formError={formError}
                      errored={errored}
                      error={saveError}
                      onShow={reveal}
                    />
                    {creating && plan !== undefined && (
                      <Text variant="secondary" size="sm">
                        {plan.autoAcceptance
                          ? t("sponsorships.form.plan_explanation.auto_acceptance", {
                              plan: plan.name,
                            })
                          : t("sponsorships.form.plan_explanation.not_auto_acceptance", {
                              plan: plan.name,
                            })}
                      </Text>
                    )}
                  </>
                }
              >
                <Button type="submit" variant="primary" loading={isSubmitting}>
                  {t("sponsorships.form.submit")}
                </Button>
                {!creating && (
                  <LinkButton href={dashboardPath(slug)} variant="secondary">
                    {t("sponsor_ui.applications.cancel")}
                  </LinkButton>
                )}
              </StickySaveBar>
            );
          }}
        </form.Subscribe>
      )}
    </form>
  );
}

type SaveResult = { errors: FormErrors | undefined; dropFile?: boolean };

const sectionId = (name: string) => `application-${name}`;

// Anchor links to the form's sections, beside it on a wide screen and hidden on a narrow one,
// where the sticky save bar keeps the page's end in reach.
function SectionList({ sections }: { sections: string[] }) {
  const t = useT();
  const { activeId, selectSection } = useTableOfContentsActiveId({
    ids: sections.map(sectionId),
  });
  return (
    <TableOfContents className="sticky top-4 hidden lg:block">
      <TableOfContents.Title>{t("sponsor_ui.applications.sections.title")}</TableOfContents.Title>
      <TableOfContents.List>
        {sections.map((name) => (
          <TableOfContents.Item
            key={name}
            href={`#${sectionId(name)}`}
            active={activeId === sectionId(name)}
            onClick={() => selectSection(sectionId(name))}
          >
            {t(`sponsor_ui.applications.sections.${name}`)}
          </TableOfContents.Item>
        ))}
      </TableOfContents.List>
    </TableOfContents>
  );
}

// Help the organizers wrote for a section, which they may leave blank.
function HelpHtml({ html, title }: { html: string; title: string }) {
  return html.trim() === "" ? null : <SandboxedHtml html={html} title={title} />;
}

// A plan's name with what it comes with, as the HAML form lists it.
function PlanLabel({ plan }: { plan: ApplicationPlan }) {
  const t = useT();
  const terms = [
    plan.priceText,
    t("sponsorships.form.plan_explanation.guests", { count: plan.numberOfGuests }),
    plan.boothEligible
      ? t("sponsorships.form.plan_explanation.booth", { count: plan.boothSize })
      : "",
    plan.talkable ? t("sponsorships.form.plan_explanation.talk") : "",
  ].filter((term) => term !== "");
  return (
    <span className="flex flex-wrap items-center gap-x-2">
      <span>{plan.name}</span>
      <Text variant="secondary" size="sm" as="span">
        {terms.join(", ")}
      </Text>
      {plan.soldOut ? (
        <Badge variant="error">{t("sponsorships.form.plan_sold_out")}</Badge>
      ) : (
        plan.closed && <Badge variant="error">{t("sponsorships.form.plan_closed")}</Badge>
      )}
    </span>
  );
}

// Beside the submit button, so a refused application is seen whichever field it concerns. The
// Connect code is for developers, so only the request ID shows.
function SaveErrorBanner({
  formError,
  errored,
  error,
  onShow,
}: {
  formError: unknown;
  errored: readonly FieldError[];
  error: unknown;
  onShow: (path: string) => void;
}) {
  const t = useT();
  const [first] = errored;
  if (typeof formError !== "string" && first === undefined) return null;
  const requestId = error === undefined ? undefined : requestIdOf(error);
  return (
    <Banner
      variant="error"
      icon={<WarningIcon />}
      title={t("sponsor_ui.applications.not_saved")}
      description={
        <div className="flex flex-col gap-2">
          {typeof formError === "string" && <div>{formError}</div>}
          {first !== undefined && (
            <div className="flex flex-wrap items-center gap-2">
              <span>
                {t("sponsor_ui.applications.fields_need_attention", {
                  count: errored.length,
                  field: labelOf(t, first.path),
                  message: first.message,
                })}
              </span>
              <Button variant="secondary" size="sm" onClick={() => onShow(first.path)}>
                {t("sponsor_ui.applications.show")}
              </Button>
            </div>
          )}
          {requestId !== undefined && (
            <Text variant="mono">
              {t("sponsor_ui.shell.error.request_id", { request_id: requestId })}
            </Text>
          )}
        </div>
      }
    />
  );
}

function labelOf(t: Translate, path: string): string {
  const keys = fieldLabelKeys(path);
  return keys.length === 0 ? path : keys.map((key) => t(key)).join(" › ");
}

function validationMessages(t: Translate): ValidationMessages {
  return {
    required: t("sponsor_ui.applications.errors.required"),
    choosePlan: t("sponsor_ui.applications.errors.choose_plan"),
    email: t("sponsor_ui.applications.errors.email"),
    url: t("sponsor_ui.applications.errors.url"),
    wholeNumber: t("sponsor_ui.applications.errors.whole_number"),
    chooseFile: t("sponsor_ui.applications.errors.choose_file"),
    acknowledge: t("sponsor_ui.applications.errors.acknowledge"),
    agree: t("sponsor_ui.applications.errors.agree"),
  };
}

// Every failed upload drops the file, so each message says what failed and what to do next. A
// file the form cannot take is the file's fault, and any other failure is the service's.
function uploadErrors(t: Translate, error: unknown, file: string): FormErrors {
  const failure = uploadFailure(error);
  switch (failure.kind) {
    case "tooLarge":
      return {
        form: t("sponsor_ui.applications.asset_file.too_large", {
          file,
          size: Number(failure.maxSize / 1_048_576n),
        }),
        fields: {},
      };
    case "unsupportedType":
      return {
        form: t("sponsor_ui.applications.asset_file.unsupported_type", { file }),
        fields: {},
      };
    case "storage":
      return { form: t("sponsor_ui.applications.asset_file.upload_failed", { file }), fields: {} };
    case "rpc":
      return {
        form: t("sponsor_ui.applications.asset_file.service_failed", { file }),
        fields: {},
      };
    default:
      return failure satisfies never;
  }
}
