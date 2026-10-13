import { Badge, Empty, LayerCard, Table, Text } from "@cloudflare/kumo";
import { ClockCounterClockwiseIcon } from "@phosphor-icons/react";
import type {
  EditingHistoryEntry,
  EditingHistoryEntry_Change,
} from "../../gen/rubykaigi/sponsor_app/editing_history_pb.ts";
import { formatDateTime } from "../../lib/dates.ts";
import { Disclosure } from "../../lib/Disclosure.tsx";
import {
  OPERATION_LABELS,
  actorOf,
  formatHistoryValue,
  isCreationEntry,
} from "./editingHistoryView.ts";
import { labelOf } from "./sponsorshipView.ts";

// Each save of a record, newest first as the RPCs list them, with a row per change.
export function EditingHistoryEntries({
  entries,
  emptyDescription,
}: {
  entries: readonly EditingHistoryEntry[];
  emptyDescription: string;
}) {
  if (entries.length === 0) {
    return (
      <Empty
        size="sm"
        icon={<ClockCounterClockwiseIcon size={32} />}
        title="No edits"
        description={emptyDescription}
      />
    );
  }

  return entries.map((entry, index) =>
    isCreationEntry(entries, index) ? (
      <LayerCard key={entry.id.toString()}>
        <LayerCard.Secondary>
          Created by <span className="font-medium">{actorOf(entry)}</span>,{" "}
          {formatDateTime(entry.createdAt)}
        </LayerCard.Secondary>
        <LayerCard.Primary>
          <Disclosure label="Show initial values">
            <Changes changes={entry.changes} />
          </Disclosure>
        </LayerCard.Primary>
      </LayerCard>
    ) : (
      <LayerCard key={entry.id.toString()}>
        <LayerCard.Secondary>
          <span className="font-medium">{actorOf(entry)}</span> edited,{" "}
          {formatDateTime(entry.createdAt)}
        </LayerCard.Secondary>
        <LayerCard.Primary>
          {entry.changes.length === 0 ? (
            <Text variant="secondary">No changes</Text>
          ) : (
            <Changes changes={entry.changes} />
          )}
        </LayerCard.Primary>
      </LayerCard>
    ),
  );
}

function Changes({ changes }: { changes: readonly EditingHistoryEntry_Change[] }) {
  return (
    <>
      <div className="hidden overflow-x-auto md:block">
        <ChangeTable changes={changes} />
      </div>
      <ChangeList changes={changes} />
    </>
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
