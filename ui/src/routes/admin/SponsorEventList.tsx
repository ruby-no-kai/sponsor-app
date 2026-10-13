import { Badge, Empty, LayerCard, Link, LinkButton, Loader, Table, Text } from "@cloudflare/kumo";
import { CalendarDotsIcon, PencilSimpleIcon } from "@phosphor-icons/react";
import { Fragment } from "react";
import { generatePath, useParams } from "react-router";
import type { AdminSponsorEvent } from "../../gen/rubykaigi/sponsor_app/admin_sponsor_events_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { formatVenueTimestamp, idToInput } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { StackedRow, TableOrStack } from "../../lib/StackedRows.tsx";
import { paths } from "../paths.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";
import { SPONSOR_EVENT_STATUS_LABELS, linkText, publishedHosts } from "./sponsorEventView.ts";
import { isWebUrl, labelOf } from "./sponsorshipView.ts";

export default function SponsorEventList() {
  const { slug = "" } = useParams();
  const { data, error } = useRpc(AdminService.method.listSponsorEvents, { conferenceSlug: slug });
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, "Events");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[{ label: conferenceName, href: generatePath(paths.conference, { slug }) }]}
        title="Sponsor events"
      />

      {data.sponsorEvents.length === 0 ? (
        <Empty
          icon={<CalendarDotsIcon size={32} />}
          title="No events"
          description="No sponsor has submitted an event yet."
        />
      ) : (
        <LayerCard className="p-0">
          <TableOrStack
            stack={data.sponsorEvents.map((event) => (
              <StackedRow key={event.id.toString()}>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <Link href={generatePath(paths.sponsorEvent, { slug, id: idToInput(event.id) })}>
                    {event.title}
                  </Link>
                  <StatusBadge event={event} />
                </div>
                <Text variant="secondary" size="sm">
                  {formatVenueTimestamp(event.startsAt)}
                </Text>
                <Hosts slug={slug} event={event} />
                <EventLink event={event} />
              </StackedRow>
            ))}
            table={
              <Table>
                <Table.Header>
                  <Table.Row>
                    <Table.Head>Title</Table.Head>
                    <Table.Head>Date/Time</Table.Head>
                    <Table.Head>Host</Table.Head>
                    <Table.Head>Status</Table.Head>
                    <Table.Head />
                  </Table.Row>
                </Table.Header>
                <Table.Body>
                  {data.sponsorEvents.map((event) => {
                    const pathParams = { slug, id: idToInput(event.id) };
                    return (
                      <Table.Row key={event.id.toString()}>
                        <Table.Cell>
                          <div className="flex flex-col gap-0.5">
                            <Link href={generatePath(paths.sponsorEvent, pathParams)}>
                              {event.title}
                            </Link>
                            <EventLink event={event} />
                          </div>
                        </Table.Cell>
                        <Table.Cell>{formatVenueTimestamp(event.startsAt)}</Table.Cell>
                        <Table.Cell>
                          <Hosts slug={slug} event={event} />
                        </Table.Cell>
                        <Table.Cell>
                          <StatusBadge event={event} />
                        </Table.Cell>
                        <Table.Cell>
                          <LinkButton
                            href={generatePath(paths.sponsorEventEdit, pathParams)}
                            variant="secondary"
                            size="sm"
                            icon={PencilSimpleIcon}
                          >
                            Edit
                          </LinkButton>
                        </Table.Cell>
                      </Table.Row>
                    );
                  })}
                </Table.Body>
              </Table>
            }
          />
        </LayerCard>
      )}
    </div>
  );
}

function StatusBadge({ event }: { event: AdminSponsorEvent }) {
  const label = labelOf(SPONSOR_EVENT_STATUS_LABELS, event.status);
  return <Badge variant={label.tone}>{label.text}</Badge>;
}

function Hosts({ slug, event }: { slug: string; event: AdminSponsorEvent }) {
  const hosts = publishedHosts(event);
  if (hosts.length === 0) return <Text variant="secondary">All withdrawn</Text>;
  return (
    <span className="min-w-0 break-words">
      {hosts.map((host, index) => (
        <Fragment key={host.id.toString()}>
          {index > 0 && ", "}
          <Link href={generatePath(paths.sponsorship, { slug, id: idToInput(host.id) })}>
            {host.name}
          </Link>
        </Fragment>
      ))}
    </span>
  );
}

function EventLink({ event }: { event: AdminSponsorEvent }) {
  return isWebUrl(event.url) ? (
    <Link href={event.url} target="_blank" rel="noreferrer" className="break-all">
      {linkText(event)}
    </Link>
  ) : (
    <Text variant="mono">{event.url}</Text>
  );
}
