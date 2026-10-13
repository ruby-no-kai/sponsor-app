import { Banner, LinkButton, Loader, Text } from "@cloudflare/kumo";
import { InfoIcon } from "@phosphor-icons/react";
import { useParams } from "react-router";
import { PassRetraction_State } from "../../gen/rubykaigi/sponsor_app/sponsor_passes_pb.ts";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { useT } from "../../lib/i18n.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { AffectedTickets, Card } from "./PassParts.tsx";
import { isRegistrationId, passRedemptionsPath, retractionRefreshInterval } from "./passesView.ts";
import { SponsorNotFound } from "./SponsorRouteError.tsx";

// A requested retraction, asked again every few seconds until the ticketing service voids it.
export default function PassRetraction() {
  const { slug = "", id = "" } = useParams();
  const t = useT();
  const valid = isRegistrationId(id);
  const { data, error } = useRpc(
    SponsorService.method.getPassRetraction,
    valid ? { conferenceSlug: slug, titoRegistrationId: id } : null,
    {
      revalidateOnFocus: false,
      refreshInterval: (latest) => retractionRefreshInterval(latest?.retraction?.state),
    },
  );
  useDocumentTitle(t("pass_retractions.show.title"), data?.conference?.name);

  if (!valid) return <SponsorNotFound />;
  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const { retraction } = data;
  if (retraction === undefined) throw new Error("GetPassRetraction returned no retraction");
  // Nothing requested yet, which the HAML page answers as not found.
  if (retraction.state === PassRetraction_State.NOT_REQUESTED) return <SponsorNotFound />;

  const back = (
    <div>
      <LinkButton href={passRedemptionsPath(slug)} variant="secondary">
        {t("pass_retractions.show.back")}
      </LinkButton>
    </div>
  );

  if (retraction.state === PassRetraction_State.COMPLETED) {
    const message = t("pass_retractions.show.completed_message");
    return (
      <div className="flex flex-col gap-4">
        <Text variant="heading" size="lg" as="h1">
          {t("pass_retractions.show.header")}
        </Text>
        <Card title={t("pass_retractions.show.completed_header")}>
          {message !== "" && <Text>{message}</Text>}
          <ul className="list-disc pl-5">
            <li>{t("pass_retractions.show.completed_note_1")}</li>
            <li>{t("pass_retractions.show.completed_note_2")}</li>
            <li>{t("pass_retractions.show.note_3")}</li>
          </ul>
          <AffectedTickets retraction={retraction} />
          {back}
        </Card>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <Text variant="heading" size="lg" as="h1">
        {t("pass_retractions.show.header")}
      </Text>
      <Banner
        icon={<InfoIcon />}
        title={t("pass_retractions.show.pending_header")}
        description={
          <div className="flex flex-col gap-2">
            <Text>{t("pass_retractions.show.pending_message")}</Text>
            <ul className="list-disc pl-5">
              <li>{t("pass_retractions.show.note_3")}</li>
            </ul>
          </div>
        }
      />
      <Card>
        <AffectedTickets retraction={retraction} />
        <dl className="grid gap-x-4 gap-y-2 md:grid-cols-[max-content_1fr]">
          <Text as="dt" bold>
            {t("pass_retractions.show.registration_reference")}
          </Text>
          <dd>{retraction.reference}</dd>
          <Text as="dt" bold>
            {t("pass_retractions.show.reason")}
          </Text>
          <dd className="break-words whitespace-pre-wrap">{retraction.reason}</dd>
        </dl>
        {back}
      </Card>
    </div>
  );
}
