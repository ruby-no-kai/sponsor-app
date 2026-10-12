import { Badge, Empty, LayerCard, Link, Loader, Table, Text } from "@cloudflare/kumo";
import { HandshakeIcon } from "@phosphor-icons/react";
import { generatePath, useParams } from "react-router";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import type { SponsorshipSummary } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { StackedRow, TableOrStack } from "../../lib/StackedRows.tsx";
import { paths } from "../paths.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";

// Every sponsorship with its plan and the notes its application carries, side by side.
export default function SponsorshipTable() {
  const { slug = "" } = useParams();
  const { data, error } = useRpc(AdminService.method.listSponsorshipTableRows, {
    conferenceSlug: slug,
  });
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, "Table view");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;

  const base = `/admin/conferences/${encodeURIComponent(slug)}`;

  const rows = data.sponsorshipTableRows.flatMap((row) =>
    row.sponsorship === undefined ? [] : [{ ...row, sponsorship: row.sponsorship }],
  );

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[{ label: conferenceName, href: generatePath(paths.conference, { slug }) }]}
        title="Table view"
      />

      {rows.length === 0 ? (
        <Empty
          icon={<HandshakeIcon size={32} />}
          title="No sponsorships"
          description="No sponsor has applied yet."
        />
      ) : (
        <LayerCard className="p-0">
          <TableOrStack
            table={
              <div className="overflow-x-auto">
                <Table layout="fixed" className="min-w-[960px]">
                  <colgroup>
                    <col className="w-48" />
                    <col className="w-28" />
                    <col className="w-36" />
                    <col />
                    <col />
                    <col />
                  </colgroup>
                  <Table.Header>
                    <Table.Row>
                      <Table.Head>Sponsorship</Table.Head>
                      <Table.Head>Plan</Table.Head>
                      <Table.Head>Displayed plan</Table.Head>
                      <Table.Head>Billing request</Table.Head>
                      <Table.Head>Customization request</Table.Head>
                      <Table.Head>Note</Table.Head>
                    </Table.Row>
                  </Table.Header>
                  <Table.Body>
                    {rows.map((row) => (
                      <Table.Row key={row.sponsorship.id.toString()}>
                        <Table.Cell className="truncate">
                          <SponsorshipLink base={base} sponsorship={row.sponsorship} />
                        </Table.Cell>
                        <Table.Cell>{row.planName}</Table.Cell>
                        <Table.Cell>{row.displayedPlanName}</Table.Cell>
                        <Note>{row.billingRequest}</Note>
                        <Note>{row.customizationRequest}</Note>
                        <Note>{row.note}</Note>
                      </Table.Row>
                    ))}
                  </Table.Body>
                </Table>
              </div>
            }
            stack={rows.map((row) => (
              <StackedRow key={row.sponsorship.id.toString()}>
                <div className="flex flex-wrap items-center gap-x-2">
                  <SponsorshipLink base={base} sponsorship={row.sponsorship} />
                </div>
                <Text variant="secondary" size="sm">
                  {row.planName}
                  {row.displayedPlanName !== undefined &&
                    row.displayedPlanName !== row.planName &&
                    ` (shown as ${row.displayedPlanName})`}
                </Text>
                <StackedNote label="Billing request">{row.billingRequest}</StackedNote>
                <StackedNote label="Customization request">{row.customizationRequest}</StackedNote>
                <StackedNote label="Note">{row.note}</StackedNote>
              </StackedRow>
            ))}
          />
        </LayerCard>
      )}
    </div>
  );
}

function SponsorshipLink({ base, sponsorship }: { base: string; sponsorship: SponsorshipSummary }) {
  return (
    <>
      <Link href={`${base}/sponsorships/${sponsorship.id}`}>{sponsorship.name}</Link>
      {sponsorship.state === SponsorshipState.WITHDRAWN && (
        <Badge variant="outline" className="ml-1">
          Withdrawn
        </Badge>
      )}
    </>
  );
}

function Note({ children }: { children: string | undefined }) {
  return <Table.Cell className="align-top whitespace-pre-wrap break-words">{children}</Table.Cell>;
}

function StackedNote({ label, children }: { label: string; children: string | undefined }) {
  if (children === undefined || children === "") return null;
  return (
    <div>
      <Text variant="secondary" size="sm">
        {label}
      </Text>
      <Text as="p" DANGEROUS_className="whitespace-pre-wrap break-words">
        {children}
      </Text>
    </div>
  );
}
