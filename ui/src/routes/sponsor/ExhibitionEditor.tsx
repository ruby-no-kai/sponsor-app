import { Banner, Button, InputArea, LinkButton, Loader, Text } from "@cloudflare/kumo";
import { InfoIcon } from "@phosphor-icons/react";
import { useForm } from "@tanstack/react-form";
import { useEffect, useState } from "react";
import { useParams } from "react-router";
import { useSWRConfig } from "swr";
import type { Exhibition } from "../../gen/rubykaigi/sponsor_app/exhibition_pb.ts";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import { joined, useFieldReveal } from "../../lib/FormParts.tsx";
import { useT } from "../../lib/i18n.tsx";
import { useGoTo } from "../../lib/navigation.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { toastManager } from "../../lib/toast.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import {
  EXHIBITION_LAYOUT,
  exhibitionInputFrom,
  exhibitionValuesFrom,
  validateExhibition,
} from "./exhibitionForm.ts";
import { SaveErrorBanner } from "./SaveErrorBanner.tsx";
import { saveFailure } from "./sponsorSave.ts";
import { exhibitionEditPath } from "./sponsorEventPaths.ts";
import { dashboardPath } from "./shellRedirects.ts";
import { SponsorNotFound } from "./SponsorRouteError.tsx";

// The booth details come with GetSponsorship, which the dashboard has already fetched.
function useBoothDetails(slug: string) {
  const { data, error } = useRpc(SponsorService.method.getSponsorship, { conferenceSlug: slug });
  if (error !== undefined && data === undefined) throw error;
  if (data !== undefined && (data.conference === undefined || data.sponsorship === undefined)) {
    throw new Error("GetSponsorship returned no sponsorship");
  }
  return data;
}

// Submits the booth details, once a booth is assigned. A sponsorship that has them edits them.
export function NewExhibition() {
  const { slug = "" } = useParams();
  const t = useT();
  const goTo = useGoTo();
  const data = useBoothDetails(slug);
  useDocumentTitle(t("exhibitions.new.title"), data?.conference?.name);
  const exists = data?.exhibition !== undefined;

  useEffect(() => {
    if (exists) goTo(exhibitionEditPath(slug), { replace: true });
  }, [exists, goTo, slug]);

  if (data === undefined || exists) return <Loader size="lg" />;
  if (!data.sponsorship?.boothAssigned) return <BoothNotAssigned slug={slug} />;
  return <ExhibitionForm slug={slug} exhibition={undefined} />;
}

// Booth details cannot be sent before a booth is assigned.
function BoothNotAssigned({ slug }: { slug: string }) {
  const t = useT();
  return (
    <div className="flex flex-col items-start gap-4">
      <Banner
        variant="alert"
        icon={<InfoIcon />}
        description={t("sponsor_ui.events.exhibition_unavailable")}
      />
      <LinkButton href={dashboardPath(slug)} variant="secondary">
        {t("sponsor_ui.events.back_to_portal")}
      </LinkButton>
    </div>
  );
}

export function EditExhibition() {
  const { slug = "" } = useParams();
  const t = useT();
  const data = useBoothDetails(slug);
  useDocumentTitle(t("exhibitions.edit.title"), data?.conference?.name);

  if (data === undefined) return <Loader size="lg" />;
  if (data.exhibition === undefined) return <SponsorNotFound />;
  return <ExhibitionForm slug={slug} exhibition={data.exhibition} />;
}

function ExhibitionForm({
  slug,
  exhibition,
}: {
  slug: string;
  exhibition: Exhibition | undefined;
}) {
  const t = useT();
  const goTo = useGoTo();
  const { mutate } = useSWRConfig();
  const createExhibition = useRpcMutation(SponsorService.method.createExhibition);
  const updateExhibition = useRpcMutation(SponsorService.method.updateExhibition);
  const creating = exhibition === undefined;
  // The error of the last save, for its request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();

  const form = useForm({
    defaultValues: exhibitionValuesFrom(exhibition),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      setSaveError(undefined);
      const invalid = validateExhibition(value, {
        required: t("sponsor_ui.events.errors.required"),
      });
      if (invalid === undefined) {
        try {
          const input = exhibitionInputFrom(value);
          if (creating) await createExhibition.trigger({ conferenceSlug: slug, input });
          else await updateExhibition.trigger({ conferenceSlug: slug, input });
          toastManager.add({
            variant: "success",
            title: t(creating ? "exhibitions.create.notice" : "exhibitions.update.notice"),
          });
          await mutate((key) => isRpcKeyOf(key, SponsorService.method.getSponsorship));
          goTo(dashboardPath(slug));
          return;
        } catch (error) {
          setSaveError(error);
          rejection.reject(formApi, value, saveFailure(error, t("sponsor_ui.shell.error.title")));
        }
      } else {
        rejection.reject(formApi, value, invalid);
      }
      const [first] = erroredFields(formApi.state.fieldMeta, EXHIBITION_LAYOUT);
      if (first !== undefined) reveal(first.path);
    },
  });

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
        {t("exhibitions.form.header")}
      </Text>
      <Banner variant="default" description={t("exhibitions.form.help")} />

      <form.Field name="description">
        {(field) => (
          <InputArea
            label={t("activerecord.attributes.exhibition.description")}
            placeholder={t("sponsor_ui.events.exhibition_placeholder")}
            data-field={field.name}
            autoResize
            minRows={6}
            maxRows={24}
            value={field.state.value}
            onValueChange={field.handleChange}
            onBlur={field.handleBlur}
            error={joined(field.state.meta.errors)}
          />
        )}
      </form.Field>

      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          errored: erroredFields(state.fieldMeta, EXHIBITION_LAYOUT),
          isSubmitting: state.isSubmitting,
        })}
      >
        {({ formError, errored, isSubmitting }) => (
          <div className="flex flex-col gap-3">
            <SaveErrorBanner
              title={t("sponsor_ui.events.exhibition_not_saved")}
              formError={formError}
              errored={errored}
              error={saveError}
              labelOf={() => t("activerecord.attributes.exhibition.description")}
              onShow={reveal}
            />
            <div className="flex flex-wrap items-center gap-2">
              <Button type="submit" variant="primary" loading={isSubmitting}>
                {t("exhibitions.form.submit")}
              </Button>
              <LinkButton href={dashboardPath(slug)} variant="secondary">
                {t("sponsor_ui.events.back_to_portal")}
              </LinkButton>
            </div>
          </div>
        )}
      </form.Subscribe>
    </form>
  );
}
