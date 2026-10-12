import { Empty, LayerCard, Link, Loader, Table, Text } from "@cloudflare/kumo";
import { TicketIcon } from "@phosphor-icons/react";
import { generatePath, useParams } from "react-router";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { paths } from "../paths.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";

// The conference tickets active sponsorships receive, which the organizers keep seats for.
export default function AttendeesKeeper() {
  const { slug = "" } = useParams();
  const { data, error } = useRpc(AdminService.method.getAttendeesKeeper, { conferenceSlug: slug });
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, "Attendees");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;

  const base = `/admin/conferences/${encodeURIComponent(slug)}`;

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[{ label: conferenceName, href: generatePath(paths.conference, { slug }) }]}
        title="Attendees"
      />

      <Text>
        {data.totalAttendees} attendees: {data.includedAttendees} included in plans,{" "}
        {data.additionalAttendees} additionally requested.
      </Text>

      {data.sponsorships.length === 0 ? (
        <Empty
          icon={<TicketIcon size={32} />}
          title="No active sponsorships"
          description="Tickets are counted once a sponsorship is accepted."
        />
      ) : (
        <LayerCard className="p-0">
          <Table>
            <Table.Header>
              <Table.Row>
                <Table.Head>Sponsorship</Table.Head>
                <Table.Head className="text-right">Total</Table.Head>
                <Table.Head className="text-right">Included</Table.Head>
                <Table.Head className="text-right">Additional</Table.Head>
              </Table.Row>
            </Table.Header>
            <Table.Body>
              {data.sponsorships.map(
                ({ sponsorship, totalAttendees, includedAttendees, additionalAttendees }) => {
                  if (sponsorship === undefined) return null;
                  return (
                    <Table.Row key={sponsorship.id.toString()}>
                      <Table.Cell>
                        <Link href={`${base}/sponsorships/${sponsorship.id}`}>
                          {sponsorship.name}
                        </Link>
                      </Table.Cell>
                      <Table.Cell className="text-right tabular-nums">{totalAttendees}</Table.Cell>
                      <Table.Cell className="text-right tabular-nums">
                        {includedAttendees}
                      </Table.Cell>
                      <Table.Cell className="text-right tabular-nums">
                        {additionalAttendees}
                      </Table.Cell>
                    </Table.Row>
                  );
                },
              )}
            </Table.Body>
          </Table>
        </LayerCard>
      )}
    </div>
  );
}
