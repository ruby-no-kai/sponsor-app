import { Collapsible, Empty, Link, Loader, Text } from "@cloudflare/kumo";
import { CaretDownIcon, EnvelopeSimpleIcon } from "@phosphor-icons/react";
import { useEffect } from "react";
import { useLocation, useParams } from "react-router";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { useT } from "../../lib/i18n.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { SandboxedHtml } from "../../lib/SandboxedHtml.tsx";
import { useDocumentTitle } from "../../lib/title.ts";
import { dashboardPath } from "./shellRedirects.ts";

// The emails the organizers sent the sponsorship, newest first.
export default function Broadcasts() {
  const { slug = "" } = useParams();
  const { hash } = useLocation();
  const t = useT();
  const { data, error } = useRpc(SponsorService.method.listBroadcastDeliveries, {
    conferenceSlug: slug,
  });
  useDocumentTitle(t("broadcasts.index.title"), data?.conference?.name);

  // The emails arrive after the page, too late for the browser to scroll to a `#broadcast-<id>`.
  const loaded = data !== undefined;
  useEffect(() => {
    if (loaded && hash !== "") document.getElementById(hash.slice(1))?.scrollIntoView();
  }, [loaded, hash]);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const { conference } = data;
  if (conference === undefined) throw new Error("ListBroadcastDeliveries returned no conference");

  return (
    <div className="flex flex-col gap-4">
      <div>
        <Link href={dashboardPath(slug)}>{t("sponsor_ui.broadcasts.back")}</Link>
      </div>
      <Text variant="heading" size="lg" as="h1">
        {t("broadcasts.index.header", { name: conference.name })}
      </Text>

      <Text>
        {t.rich("sponsor_ui.broadcasts.intro", {
          link: <Link href={dashboardPath(slug)}>{t("sponsor_ui.broadcasts.portal")}</Link>,
        })}
      </Text>

      {data.broadcastDeliveries.length === 0 ? (
        <Empty icon={<EnvelopeSimpleIcon size={32} />} title={t("broadcasts.index.empty")} />
      ) : (
        <ul className="divide-y divide-kumo-line rounded-lg bg-kumo-base ring ring-kumo-line">
          {data.broadcastDeliveries.map((delivery) => {
            const id = `broadcast-${delivery.broadcastId}`;
            return (
              <li key={delivery.broadcastId.toString()} id={id}>
                <Collapsible.Root defaultOpen={hash === `#${id}`}>
                  <Collapsible.Trigger className="group flex w-full cursor-pointer items-baseline gap-3 px-4 py-3 text-left">
                    <Text bold as="span" DANGEROUS_className="min-w-0 flex-1 break-words">
                      {delivery.title}
                    </Text>
                    {delivery.sentAt !== undefined && (
                      <Text variant="secondary" size="sm" as="span" DANGEROUS_className="shrink-0">
                        {t.dateTime(delivery.sentAt)}
                      </Text>
                    )}
                    <CaretDownIcon
                      aria-hidden
                      className="shrink-0 self-center transition-transform group-data-[panel-open]:rotate-180"
                    />
                  </Collapsible.Trigger>
                  <Collapsible.Panel className="px-4 pb-4">
                    <SandboxedHtml html={delivery.bodyHtml} title={delivery.title} />
                  </Collapsible.Panel>
                </Collapsible.Root>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
