import { toJsonString } from "@bufbuild/protobuf";
import { ValueSchema } from "@bufbuild/protobuf/wkt";
import type { Value } from "@bufbuild/protobuf/wkt";
import { EditingHistoryEntry_Change_Operation } from "../../gen/rubykaigi/sponsor_app/editing_history_pb.ts";
import type { EditingHistoryEntry } from "../../gen/rubykaigi/sponsor_app/editing_history_pb.ts";
import type { Label } from "./sponsorshipView.ts";

export const OPERATION_LABELS: Readonly<Record<EditingHistoryEntry_Change_Operation, Label>> = {
  [EditingHistoryEntry_Change_Operation.UNSPECIFIED]: { text: "?", tone: "outline" },
  [EditingHistoryEntry_Change_Operation.ADDED]: { text: "+", tone: "info" },
  [EditingHistoryEntry_Change_Operation.REMOVED]: { text: "-", tone: "error" },
  [EditingHistoryEntry_Change_Operation.CHANGED]: { text: "~", tone: "warning" },
};

// Whether an entry is the record's creation, the oldest of the entries, listed newest first, which
// adds every field.
export function isCreationEntry(entries: readonly EditingHistoryEntry[], index: number): boolean {
  const entry = entries[index];
  return (
    entry !== undefined &&
    index === entries.length - 1 &&
    entry.changes.length > 0 &&
    entry.changes.every((change) => change.operation === EditingHistoryEntry_Change_Operation.ADDED)
  );
}

// Who saved: the staff member's login, or the sponsor.
export function actorOf(entry: Pick<EditingHistoryEntry, "staffLogin">): string {
  return entry.staffLogin === undefined ? "the sponsor" : `${entry.staffLogin} (staff)`;
}

// A history value as JSON, or a dash when the change has none on that side.
export function formatHistoryValue(value: Value | undefined): string {
  return value === undefined ? "—" : toJsonString(ValueSchema, value);
}
