import { Badge, Empty, LayerCard, Loader, Table, Text } from "@cloudflare/kumo";
import { ClockCounterClockwiseIcon } from "@phosphor-icons/react";
import { generatePath, useParams } from "react-router";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import type { EditingHistoryEntry_Change } from "../../gen/rubykaigi/sponsor_app/editing_history_pb.ts";
import { formatTimestamp, idFromParam } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";
import { OPERATION_LABELS, formatHistoryValue, labelOf } from "./sponsorshipView.ts";

export default function SponsorshipEditingHistory() {
  const { slug = "", id = "" } = useParams();
  const sponsorshipId = idFromParam(id);
  if (sponsorshipId === undefined) return <NotFound />;
  return <History key={id} slug={slug} id={id} sponsorshipId={sponsorshipId} />;
}

function History({ slug, id, sponsorshipId }: { slug: string; id: string; sponsorshipId: bigint }) {
  const target = { conferenceSlug: slug, sponsorshipId };
  const history = useRpc(AdminService.method.listSponsorshipEditingHistory, target);
  const name = useRpc(AdminService.method.getSponsorship, target).data?.sponsorship?.name;
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, "Editing history", name ?? id);

  if (history.error !== undefined && history.data === undefined) throw history.error;
  if (history.data === undefined) return <Loader size="lg" />;

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[
          { label: conferenceName, href: generatePath(paths.conference, { slug }) },
          { label: name ?? id, href: generatePath(paths.sponsorship, { slug, id }) },
        ]}
        title="Editing history"
      />

      {history.data.entries.length === 0 && (
        <Empty
          size="sm"
          icon={<ClockCounterClockwiseIcon size={32} />}
          title="No edits"
          description="The sponsorship has no recorded saves."
        />
      )}
      {history.data.entries.map((entry) => (
        <LayerCard key={entry.id.toString()}>
          <LayerCard.Secondary>
            Edit at {formatTimestamp(entry.createdAt)} by{" "}
            {entry.staffLogin === undefined ? "the sponsor" : `${entry.staffLogin} (staff)`}
          </LayerCard.Secondary>
          <LayerCard.Primary>
            {entry.changes.length === 0 ? (
              <Text variant="secondary">No changes</Text>
            ) : (
              <>
                <div className="hidden overflow-x-auto md:block">
                  <ChangeTable changes={entry.changes} />
                </div>
                <ChangeList changes={entry.changes} />
              </>
            )}
          </LayerCard.Primary>
        </LayerCard>
      ))}
    </div>
  );
}

function ChangeTable({ changes }: { changes: readonly EditingHistoryEntry_Change[] }) {
  return (
    <Table>
      <Table.Header>
        <Table.Row>
          <Table.Head />
          <Table.Head>Path</Table.Head>
          <Table.Head>Before</Table.Head>
          <Table.Head>After</Table.Head>
        </Table.Row>
      </Table.Header>
      <Table.Body>
        {changes.map((change, index) => {
          const operation = labelOf(OPERATION_LABELS, change.operation);
          return (
            <Table.Row key={index}>
              <Table.Cell>
                <Badge variant={operation.tone}>{operation.text}</Badge>
              </Table.Cell>
              <Table.Cell>
                <Text variant="mono">{change.path}</Text>
              </Table.Cell>
              <Table.Cell>
                <HistoryValue text={formatHistoryValue(change.oldValue)} />
              </Table.Cell>
              <Table.Cell>
                <HistoryValue text={formatHistoryValue(change.newValue)} />
              </Table.Cell>
            </Table.Row>
          );
        })}
      </Table.Body>
    </Table>
  );
}

// The table's columns stacked per change, for a screen too narrow to show Before and After side by
// side.
function ChangeList({ changes }: { changes: readonly EditingHistoryEntry_Change[] }) {
  return (
    <ul className="flex flex-col divide-y divide-kumo-hairline md:hidden">
      {changes.map((change, index) => {
        const operation = labelOf(OPERATION_LABELS, change.operation);
        return (
          <li key={index} className="flex flex-col gap-1 py-2">
            <div className="flex flex-wrap items-center gap-2">
              <Badge variant={operation.tone}>{operation.text}</Badge>
              <Text variant="mono">
                <span className="break-all">{change.path}</span>
              </Text>
            </div>
            <dl className="grid grid-cols-[max-content_minmax(0,1fr)] gap-x-3 gap-y-1">
              <dt className="font-medium">Before</dt>
              <dd>
                <HistoryValue text={formatHistoryValue(change.oldValue)} />
              </dd>
              <dt className="font-medium">After</dt>
              <dd>
                <HistoryValue text={formatHistoryValue(change.newValue)} />
              </dd>
            </dl>
          </li>
        );
      })}
    </ul>
  );
}

function HistoryValue({ text }: { text: string }) {
  return <code className="block max-w-md whitespace-pre-wrap break-words text-sm">{text}</code>;
}
