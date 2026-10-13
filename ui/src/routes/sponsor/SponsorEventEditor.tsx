import { Banner, Button, Checkbox, Input, LinkButton, Text } from "@cloudflare/kumo";
import { WarningIcon } from "@phosphor-icons/react";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import type { ReactNode } from "react";
import { useSWRConfig } from "swr";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import type { SponsorServiceGetSponsorEventFormResponse } from "../../gen/rubykaigi/sponsor_app/sponsor_events_pb.ts";
import type { SponsorEvent } from "../../gen/rubykaigi/sponsor_app/sponsor_events_pb.ts";
import type { FormErrors } from "../../lib/errors.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import { ErrorList, Section, joined, useFieldReveal } from "../../lib/FormParts.tsx";
import type { FieldOf } from "../../lib/FormParts.tsx";
import { idFromInput } from "../../lib/forms.ts";
import { useT } from "../../lib/i18n.tsx";
import type { Translate } from "../../lib/i18n.tsx";
import { useGoTo } from "../../lib/navigation.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { callRpc, isRpcKeyOf, useRpcMutation } from "../../lib/rpc.ts";
import { SandboxedHtml } from "../../lib/SandboxedHtml.tsx";
import { toastManager } from "../../lib/toast.ts";
import { UploadOnce, extensionOf, uploadFile } from "../../lib/upload.ts";
import type { Progress } from "../../lib/upload.ts";
import { uploadFailure } from "./applicationForm.ts";
import { EventImageField } from "./EventImageField.tsx";
import { SaveErrorBanner } from "./SaveErrorBanner.tsx";
import { dashboardPath } from "./shellRedirects.ts";
import {
  FIELD_LABEL_KEYS,
  SPONSOR_EVENT_LAYOUT,
  eventImageHref,
  eventInputFrom,
  eventValuesFrom,
  needsEnglishAcknowledgement,
  validateEvent,
} from "./sponsorEventForm.ts";
import type { EventImage, SponsorEventValues } from "./sponsorEventForm.ts";
import { eventPath } from "./sponsorEventPaths.ts";
import { saveFailure } from "./sponsorSave.ts";

// The form to submit an event, and to change one the sponsor submitted.
export function SponsorEventEditor({
  slug,
  texts,
  event,
}: {
  slug: string;
  texts: SponsorServiceGetSponsorEventFormResponse;
  // The event being changed. Absent submits a new one.
  event: SponsorEvent | undefined;
}) {
  const t = useT();
  const goTo = useGoTo();
  const { mutate } = useSWRConfig();
  const createEvent = useRpcMutation(SponsorService.method.createSponsorEvent);
  const updateEvent = useRpcMutation(SponsorService.method.updateSponsorEvent);
  const creating = event === undefined;

  const [initial] = useState(() => eventValuesFrom(event));
  const [uploads] = useState(() => new UploadOnce());
  const [progress, setProgress] = useState<Progress>();
  // The error of the last save, for its request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();

  // The event's own image is uploaded again in place. Any other upload makes a new file.
  const startUpload = (file: File) => {
    const contentType = file.type === "" ? undefined : file.type;
    return initial.assetFileId.kind === "existing"
      ? callRpc(SponsorService.method.initiateSponsorEventAssetUpdate, {
          conferenceSlug: slug,
          assetFileId: idFromInput(initial.assetFileId.id),
          contentType,
        })
      : callRpc(SponsorService.method.createSponsorEventAssetUpload, {
          conferenceSlug: slug,
          contentType,
        });
  };

  const assetFileIdOf = async (choice: EventImage): Promise<bigint | undefined> => {
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
              complete: (assetFileId, versionId) =>
                callRpc(SponsorService.method.completeSponsorEventAssetUpload, {
                  conferenceSlug: slug,
                  assetFileId,
                  versionId,
                  extension: extensionOf(file.name),
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

  // Uploads the image when one is chosen, then saves. Returns the errors that kept it unsaved, and
  // the saved event's ID otherwise.
  const save = async (
    values: SponsorEventValues,
  ): Promise<{ errors: FormErrors; dropFile?: boolean } | { savedId: bigint }> => {
    setSaveError(undefined);
    const invalid = validateEvent(values, { creating }, validationMessages(t));
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
      const input = eventInputFrom(values, assetFileId);
      if (event === undefined) {
        const response = await createEvent.trigger({
          conferenceSlug: slug,
          input,
          policyAgreement: values.policyAgreement,
        });
        const created = response.sponsorEvent;
        if (created === undefined) throw new Error("CreateSponsorEvent returned no event");
        return { savedId: created.id };
      }
      await updateEvent.trigger({ conferenceSlug: slug, id: event.id, input });
      return { savedId: event.id };
    } catch (error) {
      setSaveError(error);
      return { errors: saveFailure(error, t("sponsor_ui.shell.error.title")) };
    }
  };

  const form = useForm({
    defaultValues: initial,
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      const result = await save(value);
      if ("errors" in result) {
        // A file that failed to upload would be sent again by the next save.
        if (result.dropFile === true) formApi.setFieldValue("assetFileId", initial.assetFileId);
        rejection.reject(formApi, value, result.errors);
        const [first] = erroredFields(formApi.state.fieldMeta, SPONSOR_EVENT_LAYOUT);
        if (first !== undefined) reveal(first.path);
        return;
      }
      toastManager.add({
        variant: "success",
        title: t(creating ? "sponsor_events.create.notice" : "sponsor_events.update.notice"),
      });
      await mutate(
        (key) =>
          isRpcKeyOf(key, SponsorService.method.getSponsorship) ||
          isRpcKeyOf(key, SponsorService.method.getSponsorEvent),
      );
      goTo(eventPath(slug, result.savedId));
    },
  });

  const textInput = (
    field: FieldOf<string>,
    label: string,
    {
      type = "text",
      description,
      placeholder,
      optional = false,
      step,
    }: {
      type?: string;
      description?: ReactNode;
      placeholder?: string;
      optional?: boolean;
      step?: number;
    } = {},
  ) => (
    <Input
      label={optional ? `${label} ${t("sponsorships.form.optional")}` : label}
      description={description}
      placeholder={placeholder}
      type={type}
      step={step}
      data-field={field.name}
      value={field.state.value}
      onChange={(changed) => field.handleChange(changed.target.value)}
      onBlur={field.handleBlur}
      error={joined(field.state.meta.errors)}
    />
  );

  const checkbox = (field: FieldOf<boolean>, label: ReactNode, disabled = false) => (
    <div className="flex flex-col gap-1" data-field={field.name}>
      <Checkbox
        label={label}
        checked={field.state.value}
        disabled={disabled}
        onCheckedChange={(checked) => field.handleChange(checked === true)}
      />
      <ErrorList errors={field.state.meta.errors} />
    </div>
  );

  const label = (name: keyof typeof FIELD_LABEL_KEYS) => t(FIELD_LABEL_KEYS[name] ?? name);
  const imageFile = event?.assetFile;

  return (
    <form
      ref={formRef}
      noValidate
      className="flex flex-col gap-4"
      onSubmit={(submitted) => {
        submitted.preventDefault();
        void rejection.submit(form);
      }}
    >
      <Text variant="heading" size="lg" as="h1">
        {t(creating ? "sponsor_events.new.header" : "sponsor_events.edit.header")}
      </Text>
      {texts.sponsorEventHelpHtml.trim() !== "" && (
        <SandboxedHtml html={texts.sponsorEventHelpHtml} title={t("sponsor_events.new.title")} />
      )}

      <Section title={t("sponsor_events.show.event_details")}>
        <form.Field name="title">{(field) => textInput(field, label("title"))}</form.Field>
        <form.Field name="startsAt">
          {(field) =>
            textInput(field, label("startsAt"), {
              type: "datetime-local",
              step: 60,
              description: (
                <>
                  {t("sponsor_events.form.starts_at_help")} {t("sponsor_ui.events.time_zone")}
                </>
              ),
            })
          }
        </form.Field>
        <form.Field name="url">
          {(field) =>
            textInput(field, label("url"), {
              type: "url",
              placeholder: "https://",
              description: t("sponsor_events.form.url_help"),
            })
          }
        </form.Field>
        <form.Field name="price">
          {(field) =>
            textInput(field, label("price"), {
              optional: true,
              placeholder: t("sponsor_events.form.price_placeholder"),
            })
          }
        </form.Field>
        <form.Field name="capacity">
          {(field) =>
            textInput(field, label("capacity"), {
              optional: true,
              placeholder: t("sponsor_events.form.capacity_placeholder"),
            })
          }
        </form.Field>
        <form.Field name="locationEn">
          {(field) => textInput(field, label("locationEn"), { optional: true })}
        </form.Field>
        <form.Field name="locationLocal">
          {(field) =>
            textInput(field, label("locationLocal"), {
              description: t("sponsor_events.form.location_local_help"),
            })
          }
        </form.Field>
      </Section>

      <Section title={`${t("sponsor_events.form.asset_file")} ${t("sponsorships.form.optional")}`}>
        <Text>{t("sponsor_events.form.asset_file_help")}</Text>
        <form.Field name="assetFileId">
          {(field) => (
            <EventImageField
              field={field}
              initial={initial.assetFileId}
              current={
                imageFile === undefined
                  ? undefined
                  : {
                      href: eventImageHref(slug, imageFile.id),
                      extension: imageFile.extension,
                    }
              }
              progress={progress}
            />
          )}
        </form.Field>
      </Section>

      <form.Subscribe selector={(state) => needsEnglishAcknowledgement(state.values)}>
        {(nonEnglish) =>
          nonEnglish && (
            <Banner
              variant="alert"
              icon={<WarningIcon />}
              title={t("views.sponsor_events.warnings.english.header")}
              description={
                <div className="flex flex-col gap-2">
                  <Text>{t("views.sponsor_events.warnings.english.body1")}</Text>
                  <Text>{t("views.sponsor_events.warnings.english.body2")}</Text>
                  <form.Field name="englishAcknowledged">
                    {(field) =>
                      checkbox(field, t("views.sponsor_events.warnings.english.acknowledge"))
                    }
                  </form.Field>
                </div>
              }
            />
          )
        }
      </form.Subscribe>

      <Section title={t("sponsor_ui.events.policy_title")}>
        {texts.eventPolicyHtml.trim() !== "" && (
          <SandboxedHtml html={texts.eventPolicyHtml} title={t("sponsor_ui.events.policy_title")} />
        )}
        <form.Field name="policyAgreement">
          {(field) => checkbox(field, label("policyAgreement"), !creating)}
        </form.Field>
      </Section>

      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          errored: erroredFields(state.fieldMeta, SPONSOR_EVENT_LAYOUT),
          isSubmitting: state.isSubmitting,
        })}
      >
        {({ formError, errored, isSubmitting }) => (
          <div className="flex flex-col gap-3">
            <SaveErrorBanner
              title={t("sponsor_ui.events.not_saved")}
              formError={formError}
              errored={errored}
              error={saveError}
              labelOf={(path) => label(path)}
              onShow={reveal}
            />
            <div className="flex flex-wrap items-center gap-2">
              <Button type="submit" variant="primary" loading={isSubmitting}>
                {t("sponsor_events.form.submit")}
              </Button>
              <LinkButton
                href={creating ? dashboardPath(slug) : eventPath(slug, event.id)}
                variant="secondary"
              >
                {t("sponsor_ui.events.cancel")}
              </LinkButton>
            </div>
          </div>
        )}
      </form.Subscribe>
    </form>
  );
}

function validationMessages(t: Translate) {
  return {
    required: t("sponsor_ui.events.errors.required"),
    url: t("sponsor_ui.events.errors.url"),
    datetime: t("sponsor_ui.events.errors.datetime"),
    acknowledge: t("sponsor_ui.events.errors.acknowledge"),
    agree: t("sponsor_ui.events.errors.agree"),
  };
}

// Every failed upload drops the image, so each message says what failed and what to do next. An
// image the form cannot take is the image's fault, and any other failure is the service's.
function uploadErrors(t: Translate, error: unknown, file: string): FormErrors {
  const failure = uploadFailure(error);
  switch (failure.kind) {
    case "tooLarge":
      return {
        form: t("sponsor_ui.events.image.too_large", {
          file,
          size: Number(failure.maxSize / 1_048_576n),
        }),
        fields: {},
      };
    case "unsupportedType":
      return { form: t("sponsor_ui.events.image.unsupported_type", { file }), fields: {} };
    case "storage":
      return { form: t("sponsor_ui.events.image.upload_failed", { file }), fields: {} };
    case "rpc":
      return { form: t("sponsor_ui.events.image.service_failed", { file }), fields: {} };
    default:
      return failure satisfies never;
  }
}
