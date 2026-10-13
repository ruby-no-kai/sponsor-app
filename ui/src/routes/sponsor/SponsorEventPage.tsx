import { Badge, Banner, Link, LinkButton, Loader, Text } from "@cloudflare/kumo";
import { ChatTextIcon } from "@phosphor-icons/react";
import { useParams } from "react-router";
import { useSWRConfig } from "swr";
import type { ReactNode } from "react";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { formatVenueDateTime } from "../../lib/dates.ts";
import { isWebUrl } from "../../lib/display.ts";
import { Section } from "../../lib/FormParts.tsx";
import { useT } from "../../lib/i18n.tsx";
import { useGoTo } from "../../lib/navigation.ts";
import { callRpc, isRpcKeyOf, useRpc } from "../../lib/rpc.ts";
import { toastManager } from "../../lib/toast.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { ConfirmButton } from "../admin/ConfirmButton.tsx";
import { eventStatusLabel } from "./dashboardView.ts";
import { dashboardPath } from "./shellRedirects.ts";
import { eventEditPath, eventIdFromParam } from "./sponsorEventPaths.ts";
import { eventImageHref } from "./sponsorEventForm.ts";
import { SponsorEventBack } from "./SponsorEventParts.tsx";
import { isNotFound, preconditionMessage } from "./sponsorSave.ts";
import { SponsorNotFound, notifyFailure } from "./SponsorRouteError.tsx";

// An event the sponsor submitted, with the organizers' review of it.
export default function SponsorEventPage() {
  const { slug = "", id: param } = useParams();
  const t = useT();
  const goTo = useGoTo();
  const { mutate } = useSWRConfig();
  const id = eventIdFromParam(param);
  const { data, error } = useRpc(
    SponsorService.method.getSponsorEvent,
    id === undefined ? null : { conferenceSlug: slug, id },
  );
  useDocumentTitle(
    data?.sponsorEvent?.title ?? t("sponsor_events.show.title"),
    data?.conference?.name,
  );

  if (id === undefined) return <SponsorNotFound />;
  if (error !== undefined && isNotFound(error)) return <SponsorNotFound />;
  const unmet = error === undefined ? undefined : preconditionMessage(error);
  if (unmet !== undefined) return <SponsorEventBack slug={slug} message={unmet} />;
  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const event = data.sponsorEvent;
  if (event === undefined) throw new Error("GetSponsorEvent returned no event");

  const status = eventStatusLabel(event.status);
  const withdraw = async () => {
    await callRpc(SponsorService.method.withdrawSponsorEvent, { conferenceSlug: slug, id });
    toastManager.add({ variant: "success", title: t("sponsor_events.destroy.notice") });
    await mutate(
      (key) =>
        isRpcKeyOf(key, SponsorService.method.getSponsorship) ||
        isRpcKeyOf(key, SponsorService.method.getSponsorEvent),
    );
    goTo(dashboardPath(slug));
  };

  const detail = (label: string, value: ReactNode) => (
    <div className="flex flex-col">
      <dt className="font-semibold">{label}</dt>
      <dd className="break-words">{value}</dd>
    </div>
  );
  const attribute = (name: string) => t(`activerecord.attributes.sponsor_event.${name}`);

  return (
    <div className="flex flex-col gap-4">
      <header className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
        <div className="flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1">
          <Text variant="heading" size="lg" as="h1" DANGEROUS_className="min-w-0 break-words">
            {event.title}
          </Text>
          <Badge variant={status.tone}>{t(status.key)}</Badge>
        </div>
        {event.editable && (
          <div className="flex flex-wrap items-center gap-2">
            <LinkButton href={eventEditPath(slug, id)} variant="primary">
              {t("sponsor_events.show.edit")}
            </LinkButton>
            <ConfirmButton
              label={t("sponsor_events.show.withdraw")}
              triggerVariant="secondary-destructive"
              title={t("sponsor_ui.events.withdraw_title", { title: event.title })}
              description={t("sponsor_events.show.withdraw_confirm")}
              confirmLabel={t("sponsor_events.show.withdraw")}
              cancelLabel={t("sponsor_ui.events.cancel")}
              onConfirm={withdraw}
              onError={(failure) => notifyFailure(t, failure)}
            />
          </div>
        )}
      </header>

      {event.adminComment !== "" && (
        <Banner
          variant="alert"
          icon={<ChatTextIcon />}
          title={attribute("admin_comment")}
          description={<span className="whitespace-pre-wrap">{event.adminComment}</span>}
        />
      )}

      <Section title={t("sponsor_events.show.event_details")}>
        <dl className="flex flex-col gap-3">
          {event.startsAt !== undefined &&
            detail(attribute("starts_at"), formatVenueDateTime(event.startsAt, t.locale))}
          {detail(
            attribute("url"),
            isWebUrl(event.url) ? (
              <Link href={event.url} target="_blank" rel="noreferrer">
                {event.url}
              </Link>
            ) : (
              event.url
            ),
          )}
          {event.price !== "" && detail(attribute("price"), event.price)}
          {event.capacity !== "" && detail(attribute("capacity"), event.capacity)}
          {event.locationEn !== "" && detail(attribute("location_en"), event.locationEn)}
          {event.locationLocal !== "" && detail(attribute("location_local"), event.locationLocal)}
          {event.assetFile !== undefined &&
            detail(
              t("sponsor_events.form.asset_file"),
              <Link
                href={eventImageHref(slug, event.assetFile.id)}
                target="_blank"
                rel="noreferrer"
              >
                {t("sponsor_ui.events.image.download", { extension: event.assetFile.extension })}
              </Link>,
            )}
        </dl>
      </Section>

      <div>
        <LinkButton href={dashboardPath(slug)} variant="secondary">
          {t("sponsor_events.show.back_to_sponsorship")}
        </LinkButton>
      </div>
    </div>
  );
}
