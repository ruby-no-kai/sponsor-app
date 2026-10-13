import { Badge, Empty, LayerCard, Link, LinkButton, Loader, Table, Text } from "@cloudflare/kumo";
import { EnvelopeSimpleIcon, PlusIcon } from "@phosphor-icons/react";
import { generatePath, useParams } from "react-router";
import type { AdminBroadcastSummary } from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { formatTimestamp } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { StackedRow, TableOrStack } from "../../lib/StackedRows.tsx";
import { paths } from "../paths.ts";
import { BROADCAST_STATUS_LABELS, refreshIntervalFor } from "./broadcastView.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";
import { labelOf } from "./sponsorshipView.ts";

export default function BroadcastList() {
  const { slug = "" } = useParams();
  const { data, error } = useRpc(
    AdminService.method.listBroadcasts,
    { conferenceSlug: slug },
    {
      refreshInterval: (latest) =>
        refreshIntervalFor(latest?.broadcasts.map((broadcast) => broadcast.status) ?? []),
    },
  );
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, "Broadcasts");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;

  const newBroadcast = generatePath(paths.broadcastNew, { slug });

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[{ label: conferenceName, href: generatePath(paths.conference, { slug }) }]}
        title="Broadcasts"
        actions={
          <LinkButton href={newBroadcast} variant="primary" icon={PlusIcon}>
            New broadcast
          </LinkButton>
        }
      />

      {data.broadcasts.length === 0 ? (
        <Empty
          icon={<EnvelopeSimpleIcon size={32} />}
          title="No broadcasts"
          description="Nothing has been emailed to this conference's sponsors from here yet."
          contents={
            <LinkButton href={newBroadcast} variant="secondary" icon={PlusIcon}>
              Write the first broadcast
            </LinkButton>
          }
        />
      ) : (
        <LayerCard className="p-0">
          <TableOrStack
            stack={data.broadcasts.map((broadcast) => (
              <StackedRow key={broadcast.id.toString()}>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <BroadcastLink slug={slug} broadcast={broadcast} />
                  <StatusBadge broadcast={broadcast} />
                </div>
                <Text variant="secondary" size="sm">
                  {broadcast.campaign}
                </Text>
                {broadcast.dispatchedAt !== undefined && (
                  <Text variant="secondary" size="sm">
                    Dispatched {formatTimestamp(broadcast.dispatchedAt)}
                  </Text>
                )}
              </StackedRow>
            ))}
            table={
              <Table>
                <Table.Header>
                  <Table.Row>
                    <Table.Head>Title</Table.Head>
                    <Table.Head>Status</Table.Head>
                    <Table.Head>Dispatched at</Table.Head>
                  </Table.Row>
                </Table.Header>
                <Table.Body>
                  {data.broadcasts.map((broadcast) => (
                    <Table.Row key={broadcast.id.toString()}>
                      <Table.Cell>
                        <div className="flex flex-col">
                          <BroadcastLink slug={slug} broadcast={broadcast} />
                          <Text variant="secondary" size="sm">
                            {broadcast.campaign}
                          </Text>
                        </div>
                      </Table.Cell>
                      <Table.Cell>
                        <StatusBadge broadcast={broadcast} />
                      </Table.Cell>
                      <Table.Cell>{formatTimestamp(broadcast.dispatchedAt, "")}</Table.Cell>
                    </Table.Row>
                  ))}
                </Table.Body>
              </Table>
            }
          />
        </LayerCard>
      )}
    </div>
  );
}

function BroadcastLink({ slug, broadcast }: { slug: string; broadcast: AdminBroadcastSummary }) {
  return (
    <Link href={generatePath(paths.broadcast, { slug, id: broadcast.id.toString() })}>
      {broadcast.title}
    </Link>
  );
}

function StatusBadge({ broadcast }: { broadcast: AdminBroadcastSummary }) {
  const status = labelOf(BROADCAST_STATUS_LABELS, broadcast.status);
  return <Badge variant={status.tone}>{status.text}</Badge>;
}
