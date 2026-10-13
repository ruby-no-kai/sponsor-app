import { Badge, Empty, Link, LinkButton, Loader, Table, Text } from "@cloudflare/kumo";
import { PencilSimpleIcon, UsersIcon } from "@phosphor-icons/react";
import { generatePath, useParams } from "react-router";
import { AdminBroadcast_Status } from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import type { AdminBroadcastDelivery } from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { idFromParam } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import { Section } from "./FormParts.tsx";
import { SandboxedHtml } from "./SandboxedHtml.tsx";
import { StackedRow, TableOrStack } from "../../lib/StackedRows.tsx";
import {
  BROADCAST_STATUS_LABELS,
  DELIVERY_STATUS_LABELS,
  isBusy,
  refreshIntervalFor,
} from "./broadcastView.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";
import { labelOf } from "./sponsorshipView.ts";

export default function BroadcastDetail() {
  const { slug = "", id = "" } = useParams();
  const broadcastId = idFromParam(id);
  if (broadcastId === undefined) return <NotFound />;
  return <Detail key={id} slug={slug} id={id} broadcastId={broadcastId} />;
}

function Detail({ slug, id, broadcastId }: { slug: string; id: string; broadcastId: bigint }) {
  const { data, error } = useRpc(
    AdminService.method.getBroadcast,
    { conferenceSlug: slug, broadcastId },
    {
      refreshInterval: (latest) =>
        refreshIntervalFor(latest?.broadcast === undefined ? [] : [latest.broadcast.status]),
    },
  );
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, `Broadcast: ${data?.broadcast?.campaign ?? id}`);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const { broadcast, deliveries } = data;
  if (broadcast === undefined) throw new Error("GetBroadcast returned no broadcast");

  const status = labelOf(BROADCAST_STATUS_LABELS, broadcast.status);

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[
          { label: conferenceName, href: generatePath(paths.conference, { slug }) },
          { label: "Broadcasts", href: generatePath(paths.broadcasts, { slug }) },
        ]}
        title={
          <span className="inline-flex flex-wrap items-center gap-2">
            {broadcast.campaign}
            <Badge variant={status.tone}>{status.text}</Badge>
            {isBusy(broadcast.status) && <Loader size="sm" />}
          </span>
        }
        subtitle={broadcast.description === "" ? undefined : broadcast.description}
        actions={
          <LinkButton
            href={generatePath(paths.broadcastEdit, { slug, id })}
            variant="primary"
            icon={PencilSimpleIcon}
          >
            Edit
          </LinkButton>
        }
      />

      <Section title="Email">
        <Text variant="heading" as="h3">
          {broadcast.title}
        </Text>
        <SandboxedHtml html={broadcast.bodyHtml} title="Body" compact placeholders={["@LOGIN@"]} />
      </Section>

      <Section title={`Recipients (${deliveries.length})`}>
        {broadcast.status !== AdminBroadcast_Status.READY && (
          <Text variant="secondary">{recipientsNote(broadcast.status)}</Text>
        )}
        <Deliveries slug={slug} deliveries={deliveries} />
      </Section>
    </div>
  );
}

function recipientsNote(status: AdminBroadcast_Status): string {
  switch (status) {
    case AdminBroadcast_Status.CREATED:
    case AdminBroadcast_Status.PREPARING:
    case AdminBroadcast_Status.MODIFYING:
      return "Collecting recipients. Recipients can be added again once the broadcast is ready.";
    default:
      return "The broadcast has been dispatched, so its recipients can no longer change.";
  }
}

function Deliveries({
  slug,
  deliveries,
}: {
  slug: string;
  deliveries: readonly AdminBroadcastDelivery[];
}) {
  if (deliveries.length === 0) {
    return (
      <Empty
        icon={<UsersIcon size={32} />}
        title="No recipients"
        description="Nobody gets this broadcast yet."
      />
    );
  }

  return (
    <TableOrStack
      stack={deliveries.map((delivery) => (
        <DeliveryStackedRow key={delivery.id.toString()} slug={slug} delivery={delivery} />
      ))}
      table={
        <Table>
          <Table.Header>
            <Table.Row>
              <Table.Head>Name</Table.Head>
              <Table.Head>Email</Table.Head>
              <Table.Head>Status</Table.Head>
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {deliveries.map((delivery) => (
              <DeliveryRow key={delivery.id.toString()} slug={slug} delivery={delivery} />
            ))}
          </Table.Body>
        </Table>
      }
    />
  );
}

type DeliveryProps = { slug: string; delivery: AdminBroadcastDelivery };

function DeliveryRow({ slug, delivery }: DeliveryProps) {
  return (
    <Table.Row>
      <Table.Cell>
        <DeliveryName slug={slug} delivery={delivery} />
      </Table.Cell>
      <Table.Cell>
        <DeliveryEmail delivery={delivery} />
      </Table.Cell>
      <Table.Cell>
        <DeliveryStatus delivery={delivery} />
      </Table.Cell>
    </Table.Row>
  );
}

function DeliveryStackedRow({ slug, delivery }: DeliveryProps) {
  return (
    <StackedRow>
      <DeliveryName slug={slug} delivery={delivery} />
      <DeliveryEmail delivery={delivery} />
      <div>
        <DeliveryStatus delivery={delivery} />
      </div>
    </StackedRow>
  );
}

function DeliveryName({ slug, delivery }: { slug: string; delivery: AdminBroadcastDelivery }) {
  const { sponsorship } = delivery;
  if (sponsorship === undefined) return <Text variant="secondary">{delivery.email}</Text>;
  return (
    <div className="flex flex-col">
      <Link
        href={generatePath(paths.sponsorship, {
          slug: sponsorship.conferenceSlug,
          id: sponsorship.id.toString(),
        })}
      >
        {sponsorship.name}
      </Link>
      {sponsorship.conferenceSlug !== slug && (
        <Text variant="secondary" size="sm">
          {sponsorship.conferenceSlug}
        </Text>
      )}
    </div>
  );
}

function DeliveryEmail({ delivery }: { delivery: AdminBroadcastDelivery }) {
  return (
    <div className="flex min-w-0 flex-col break-all">
      <span>{delivery.email}</span>
      {delivery.ccEmails.length > 0 && (
        <Text variant="secondary" size="sm">
          CC: {delivery.ccEmails.join(", ")}
        </Text>
      )}
    </div>
  );
}

function DeliveryStatus({ delivery }: { delivery: AdminBroadcastDelivery }) {
  const status = labelOf(DELIVERY_STATUS_LABELS, delivery.status);
  return <Badge variant={status.tone}>{status.text}</Badge>;
}
