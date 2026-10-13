import { Banner, Button, Checkbox, InputArea, LinkButton, Loader, Text } from "@cloudflare/kumo";
import { InfoIcon, WarningIcon } from "@phosphor-icons/react";
import { useForm } from "@tanstack/react-form";
import { useEffect, useState } from "react";
import type { ReactNode } from "react";
import { useParams } from "react-router";
import { useSWRConfig } from "swr";
import { ProblemType } from "../../gen/rubykaigi/sponsor_app/problem_pb.ts";
import { PassRetraction_State } from "../../gen/rubykaigi/sponsor_app/sponsor_passes_pb.ts";
import type { PassRetraction } from "../../gen/rubykaigi/sponsor_app/sponsor_passes_pb.ts";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { fieldViolations, problemDetailsOf, problemTypeOf, requestIdOf } from "../../lib/errors.ts";
import { useT } from "../../lib/i18n.tsx";
import { joined } from "../../lib/FormParts.tsx";
import { useGoTo } from "../../lib/navigation.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { AffectedTickets, Card } from "./PassParts.tsx";
import {
  isRegistrationId,
  passRedemptionsPath,
  retractionErrors,
  retractionInputFrom,
  retractionPath,
  retractionValuesFrom,
} from "./passesView.ts";
import { SponsorNotFound } from "./SponsorRouteError.tsx";

// Asks to void a registration. A retraction already completed has its own page.
export default function PassRetractionForm() {
  const { slug = "", id = "" } = useParams();
  const t = useT();
  const goTo = useGoTo();
  const valid = isRegistrationId(id);
  // Before a retraction is requested, each answer asks the ticketing service.
  const { data, error } = useRpc(
    SponsorService.method.getPassRetraction,
    valid ? { conferenceSlug: slug, titoRegistrationId: id } : null,
    { revalidateOnFocus: false },
  );
  useDocumentTitle(t("pass_retractions.new.title"), data?.conference?.name);

  const completed = data?.retraction?.state === PassRetraction_State.COMPLETED;
  useEffect(() => {
    if (completed) goTo(retractionPath(slug, id), { replace: true });
  }, [completed, goTo, slug, id]);

  if (!valid) return <SponsorNotFound />;
  if (error !== undefined && data === undefined) throw error;
  if (data === undefined || completed) return <Loader size="lg" />;
  const { conference, retraction } = data;
  if (conference === undefined || retraction === undefined) {
    throw new Error("GetPassRetraction returned no retraction");
  }

  const back = (
    <div>
      <LinkButton href={passRedemptionsPath(slug)} variant="secondary">
        {t("pass_retractions.new.cancel")}
      </LinkButton>
    </div>
  );

  return (
    <div className="flex flex-col gap-4">
      <Text variant="heading" size="lg" as="h1">
        {t("pass_retractions.new.header")}
      </Text>
      <Card title={t("pass_retractions.new.description", { reference: retraction.reference })}>
        {!data.retractionEnabled && (
          <Banner
            variant="alert"
            icon={<WarningIcon />}
            description={
              <span
                className="[&_a]:break-all [&_a]:underline"
                dangerouslySetInnerHTML={{
                  __html: t.html("pass_retractions.new.disabled_message_html", {
                    contact_email: conference.contactEmailAddress,
                  }),
                }}
              />
            }
          />
        )}

        <AffectedTickets retraction={retraction} />

        {!retraction.retractable ? (
          <>
            <Banner
              variant="error"
              icon={<WarningIcon />}
              description={t("pass_retractions.new.not_retractable")}
            />
            {back}
          </>
        ) : data.retractionEnabled ? (
          <RetractionForm
            slug={slug}
            id={id}
            retraction={retraction}
            conferenceName={conference.name}
            back={back}
          />
        ) : (
          back
        )}
      </Card>
    </div>
  );
}

function RetractionForm({
  slug,
  id,
  retraction,
  conferenceName,
  back,
}: {
  slug: string;
  id: string;
  retraction: PassRetraction;
  conferenceName: string;
  back: ReactNode;
}) {
  const t = useT();
  const { mutate } = useSWRConfig();
  const createRetraction = useRpcMutation(SponsorService.method.createPassRetraction);
  // The error of the last request, for its message and request ID.
  const [requestError, setRequestError] = useState<unknown>();

  const rejection = useSaveRejection();
  const form = useForm({
    defaultValues: retractionValuesFrom(retraction),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      const invalid = retractionErrors(value, t);
      if (invalid !== undefined) {
        rejection.reject(formApi, value, invalid);
        return;
      }
      try {
        await createRetraction.trigger({
          conferenceSlug: slug,
          titoRegistrationId: id,
          input: retractionInputFrom(value),
        });
      } catch (error) {
        setRequestError(error);
        rejection.reject(formApi, value, fieldViolations(error, { prefix: "input." }));
        return;
      }
      // The retraction now reads as completed, upon which the page moves to it.
      await mutate((key) => isRpcKeyOf(key, SponsorService.method.getPassRetraction));
    },
  });

  return (
    <form
      noValidate
      className="flex flex-col gap-4"
      onSubmit={(event) => {
        event.preventDefault();
        setRequestError(undefined);
        void rejection.submit(form);
      }}
    >
      <form.Field name="reason">
        {(field) => (
          <InputArea
            label={t("pass_retractions.new.reason_label")}
            placeholder={t("pass_retractions.new.reason_placeholder")}
            autoResize
            minRows={4}
            maxRows={12}
            value={field.state.value}
            onValueChange={field.handleChange}
            error={joined(field.state.meta.errors)}
          />
        )}
      </form.Field>

      <Banner
        icon={<InfoIcon />}
        title={t("pass_retractions.new.notes_header")}
        description={
          <ul className="list-disc pl-5">
            <li>{t("pass_retractions.new.note_1")}</li>
            <li>{t("pass_retractions.new.note_2", { conference_name: conferenceName })}</li>
            <li>{t("pass_retractions.new.note_3")}</li>
          </ul>
        }
      />

      <form.Field name="confirmed">
        {(field) => {
          const message = joined(field.state.meta.errors);
          return (
            <div className="flex flex-col gap-1">
              <Checkbox
                label={t("pass_retractions.new.confirmation_label")}
                checked={field.state.value}
                onCheckedChange={(checked) => field.handleChange(checked === true)}
                variant={message === undefined ? "default" : "error"}
              />
              {message !== undefined && (
                <Text variant="error" size="sm">
                  {message}
                </Text>
              )}
            </div>
          );
        }}
      </form.Field>

      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          isSubmitting: state.isSubmitting,
        })}
      >
        {({ formError, isSubmitting }) => (
          <>
            <RequestErrorBanner error={requestError} formError={formError} />
            <div className="flex flex-wrap items-center gap-2">
              <Button type="submit" variant="destructive" loading={isSubmitting}>
                {t("pass_retractions.new.submit")}
              </Button>
              {back}
            </div>
          </>
        )}
      </form.Subscribe>
    </form>
  );
}

// Rails words a rejected record's message in the sponsor's language. Any other error shows its
// problem's title, which the server words in it too.
function RequestErrorBanner({ error, formError }: { error: unknown; formError: unknown }) {
  const t = useT();
  if (error === undefined) return null;
  const message =
    problemTypeOf(error) === ProblemType.INVALID_RECORD && typeof formError === "string"
      ? formError
      : problemDetailsOf(error)?.title || t("sponsor_ui.shell.error.description");
  const requestId = requestIdOf(error);
  return (
    <Banner
      variant="error"
      icon={<WarningIcon />}
      title={t("pass_retractions.create.error")}
      description={
        <>
          <Text>{message}</Text>
          {requestId !== undefined && (
            <Text variant="mono">
              {t("sponsor_ui.shell.error.request_id", { request_id: requestId })}
            </Text>
          )}
        </>
      }
    />
  );
}
