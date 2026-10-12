import { Badge, Empty, LayerCard, Link, LinkButton, Loader, Table, Text } from "@cloudflare/kumo";
import { CalendarBlankIcon, PlusIcon } from "@phosphor-icons/react";
import { generatePath } from "react-router";
import type { Conference } from "../../gen/rubykaigi/sponsor_app/conference_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { formatDateRange } from "../../lib/dates.ts";
import { useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { paths } from "../paths.ts";

function applicationWindow(conference: Conference): string {
  if (conference.applicationOpensAt === undefined) return "Not scheduled";
  return formatDateRange(conference.applicationOpensAt, conference.applicationClosesAt, {
    from: "Not scheduled",
    to: "no deadline",
  });
}

export default function ConferenceList() {
  const { data, error } = useRpc(AdminService.method.listConferences, {});
  const viewer = useRpc(AdminService.method.getViewer, {}).data?.staff;
  useDocumentTitle("Conferences");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <Text variant="heading" size="lg" as="h2">
          Conferences
        </Text>
        {viewer !== undefined && !viewer.restricted && (
          <LinkButton href={paths.conferenceNew} variant="primary" icon={PlusIcon}>
            New conference
          </LinkButton>
        )}
      </div>

      {data.conferences.length === 0 ? (
        <Empty
          icon={<CalendarBlankIcon size={32} />}
          title="No conferences"
          description="There is no conference you can manage yet."
        />
      ) : (
        <LayerCard className="p-0">
          <Table>
            <Table.Header>
              <Table.Row>
                <Table.Head>Name</Table.Head>
                <Table.Head>Slug</Table.Head>
                <Table.Head>Application window</Table.Head>
                <Table.Head />
              </Table.Row>
            </Table.Header>
            <Table.Body>
              {data.conferences.map(({ conference, hidden }) => {
                if (conference === undefined) return null;
                return (
                  <Table.Row key={conference.slug}>
                    <Table.Cell>
                      <Link href={generatePath(paths.conference, { slug: conference.slug })}>
                        {conference.name}
                      </Link>
                    </Table.Cell>
                    <Table.Cell>
                      <Text variant="mono">{conference.slug}</Text>
                    </Table.Cell>
                    <Table.Cell>{applicationWindow(conference)}</Table.Cell>
                    <Table.Cell>{hidden && <Badge variant="outline">Hidden</Badge>}</Table.Cell>
                  </Table.Row>
                );
              })}
            </Table.Body>
          </Table>
        </LayerCard>
      )}
    </div>
  );
}
