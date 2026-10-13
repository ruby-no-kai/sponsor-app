import { Badge, LayerCard, Link, LinkButton, Loader, Text } from "@cloudflare/kumo";
import { ClockCounterClockwiseIcon, PencilSimpleIcon } from "@phosphor-icons/react";
import type { ReactNode } from "react";
import { generatePath, useParams } from "react-router";
import type { AdminSponsorEvent } from "../../gen/rubykaigi/sponsor_app/admin_sponsor_events_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { isWebUrl } from "../../lib/display.ts";
import { formatTimestamp, formatVenueTimestamp, idFromParam, idToInput } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";
import { SPONSOR_EVENT_STATUS_LABELS } from "./sponsorEventView.ts";
import { labelOf } from "./sponsorshipView.ts";

export default function SponsorEventDetail() {
  const { slug = "", id = "" } = useParams();
  const sponsorEventId = idFromParam(id);
  if (sponsorEventId === undefined) return <NotFound />;
  return <Detail key={id} slug={slug} id={id} sponsorEventId={sponsorEventId} />;
}

function Detail({
  slug,
  id,
  sponsorEventId,
}: {
  slug: string;
  id: string;
  sponsorEventId: bigint;
}) {
  const { data, error } = useRpc(AdminService.method.getSponsorEvent, {
    conferenceSlug: slug,
    sponsorEventId,
  });
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, data?.sponsorEvent?.title ?? id);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const event = data.sponsorEvent;
  if (event === undefined) throw new Error("GetSponsorEvent returned no event");

  const pathParams = { slug, id };
  const { sponsorship } = event;

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[
          { label: conferenceName, href: generatePath(paths.conference, { slug }) },
          { label: "Events", href: generatePath(paths.sponsorEvents, { slug }) },
        ]}
        title={event.title}
        actions={
          <>
            <LinkButton
              href={generatePath(paths.sponsorEventEdit, pathParams)}
              variant="primary"
              icon={PencilSimpleIcon}
            >
              Edit
            </LinkButton>
            <LinkButton
              href={generatePath(paths.sponsorEventEditingHistory, pathParams)}
              variant="secondary"
              icon={ClockCounterClockwiseIcon}
            >
              History
            </LinkButton>
          </>
        }
      />

      <div className="grid gap-4 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <EventDetails
            event={event}
            downloadHref={`/admin/conferences/${encodeURIComponent(slug)}/events/${event.id}/download_asset`}
          />
        </div>
        <div className="flex flex-col gap-4">
          <Card title="Status">
            <div>
              <StatusBadge event={event} />
            </div>
            <Text>
              Policy acknowledged:{" "}
              {event.policyAcknowledgedAt === undefined
                ? "Not acknowledged"
                : formatTimestamp(event.policyAcknowledgedAt)}
            </Text>
          </Card>
          <Card title="Sponsorship">
            {sponsorship === undefined ? (
              <Text variant="secondary">Unknown</Text>
            ) : (
              <Link href={generatePath(paths.sponsorship, { slug, id: idToInput(sponsorship.id) })}>
                {sponsorship.name}
              </Link>
            )}
          </Card>
          {event.coHosts.length > 0 && (
            <Card title="Co-hosts">
              <ul className="flex flex-col gap-1">
                {event.coHosts.map((coHost) => (
                  <li key={coHost.id.toString()} className="flex flex-wrap items-center gap-2">
                    <Link
                      href={generatePath(paths.sponsorship, { slug, id: idToInput(coHost.id) })}
                    >
                      {coHost.name}
                    </Link>
                    {coHost.state === SponsorshipState.WITHDRAWN && (
                      <Badge variant="outline">Withdrawn</Badge>
                    )}
                  </li>
                ))}
              </ul>
            </Card>
          )}
          {event.adminComment !== "" && (
            <Card title="Admin comment">
              <Text>
                <span className="whitespace-pre-wrap">{event.adminComment}</span>
              </Text>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}

function EventDetails({ event, downloadHref }: { event: AdminSponsorEvent; downloadHref: string }) {
  return (
    <Card title="Event details">
      <dl className="grid grid-cols-[max-content_1fr] gap-x-3 gap-y-1">
        <Term label="Title">{event.title}</Term>
        <Term label="Slug">
          <Text variant="mono">{event.slug}</Text>
        </Term>
        <Term label="Starts at">{formatVenueTimestamp(event.startsAt)}</Term>
        <Term label="URL">
          {isWebUrl(event.url) ? (
            <Link href={event.url} target="_blank" rel="noreferrer" className="break-all">
              {event.url}
            </Link>
          ) : (
            <Text variant="mono">{event.url}</Text>
          )}
        </Term>
        {event.linkName !== "" && <Term label="Link name">{event.linkName}</Term>}
        {event.price !== "" && <Term label="Price">{event.price}</Term>}
        {event.capacity !== "" && <Term label="Capacity">{event.capacity}</Term>}
        {event.locationEn !== "" && <Term label="Location (English)">{event.locationEn}</Term>}
        {event.locationLocal !== "" && <Term label="Location (local)">{event.locationLocal}</Term>}
        <Term label="Hero image">
          {event.heroImageUploaded ? (
            <Link href={downloadHref}>Download</Link>
          ) : (
            <Text variant="secondary">Not uploaded</Text>
          )}
        </Term>
      </dl>
    </Card>
  );
}

function StatusBadge({ event }: { event: AdminSponsorEvent }) {
  const label = labelOf(SPONSOR_EVENT_STATUS_LABELS, event.status);
  return <Badge variant={label.tone}>{label.text}</Badge>;
}

function Card({ title, children }: { title: string; children: ReactNode }) {
  return (
    <LayerCard>
      <LayerCard.Secondary>{title}</LayerCard.Secondary>
      <LayerCard.Primary className="flex flex-col gap-2">{children}</LayerCard.Primary>
    </LayerCard>
  );
}

function Term({ label, children }: { label: string; children: ReactNode }) {
  return (
    <>
      <dt className="font-medium">{label}</dt>
      <dd className="min-w-0 break-words">{children}</dd>
    </>
  );
}
