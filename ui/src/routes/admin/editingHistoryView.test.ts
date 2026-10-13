import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import { ValueSchema } from "@bufbuild/protobuf/wkt";
import {
  EditingHistoryEntry_Change_Operation,
  EditingHistoryEntrySchema,
} from "../../gen/rubykaigi/sponsor_app/editing_history_pb.ts";
import {
  OPERATION_LABELS,
  actorOf,
  formatHistoryValue,
  isCreationEntry,
} from "./editingHistoryView.ts";
import { labelOf } from "./sponsorshipView.ts";

describe("OPERATION_LABELS", () => {
  it("marks each operation as the HAML history page does", () => {
    assert.equal(labelOf(OPERATION_LABELS, EditingHistoryEntry_Change_Operation.ADDED).text, "+");
    assert.equal(labelOf(OPERATION_LABELS, EditingHistoryEntry_Change_Operation.REMOVED).text, "-");
    assert.equal(labelOf(OPERATION_LABELS, EditingHistoryEntry_Change_Operation.CHANGED).text, "~");
  });
});

describe("formatHistoryValue", () => {
  it("shows JSON, and a dash for no value", () => {
    assert.equal(formatHistoryValue(undefined), "—");
    assert.equal(
      formatHistoryValue(create(ValueSchema, { kind: { case: "nullValue", value: 0 } })),
      "null",
    );
    assert.equal(
      formatHistoryValue(create(ValueSchema, { kind: { case: "stringValue", value: "a" } })),
      '"a"',
    );
  });
});

const added = { operation: EditingHistoryEntry_Change_Operation.ADDED, path: "name" };
const changed = { operation: EditingHistoryEntry_Change_Operation.CHANGED, path: "name" };

describe("isCreationEntry", () => {
  it("is the oldest entry when it only adds fields", () => {
    const entries = [
      create(EditingHistoryEntrySchema, { changes: [changed] }),
      create(EditingHistoryEntrySchema, { changes: [added] }),
    ];
    assert.equal(isCreationEntry(entries, 1), true);
    assert.equal(isCreationEntry(entries, 0), false);
  });

  it("is not an oldest entry that changes something", () => {
    assert.equal(
      isCreationEntry([create(EditingHistoryEntrySchema, { changes: [added, changed] })], 0),
      false,
    );
  });
});

describe("actorOf", () => {
  it("names the staff member or the sponsor", () => {
    assert.equal(actorOf({ staffLogin: "sorah" }), "sorah (staff)");
    assert.equal(actorOf({ staffLogin: undefined }), "the sponsor");
  });
});
