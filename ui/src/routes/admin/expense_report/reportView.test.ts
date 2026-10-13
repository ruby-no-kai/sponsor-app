import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import {
  ExpenseReportSchema,
  ExpenseReport_Status,
} from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { fileName, hashOf, isReadOnly, selectionFromHash, unlinkedFiles } from "./reportView.ts";

describe("isReadOnly", () => {
  it("holds for an approved report only", () => {
    assert.ok(isReadOnly({ status: ExpenseReport_Status.APPROVED }));
    assert.ok(!isReadOnly({ status: ExpenseReport_Status.SUBMITTED }));
    assert.ok(!isReadOnly({ status: ExpenseReport_Status.REJECTED }));
  });
});

describe("unlinkedFiles", () => {
  it("lists the files no line item attaches", () => {
    const report = create(ExpenseReportSchema, {
      lineItems: [
        { id: "1", fileIds: ["10"] },
        { id: "2", fileIds: ["10", "11"] },
      ],
      files: [{ id: "10" }, { id: "11" }, { id: "12", filename: "loose.pdf" }],
    });

    assert.deepEqual(
      unlinkedFiles(report).map((file) => fileName(file)),
      ["loose.pdf"],
    );
    assert.equal(fileName({ id: "11", filename: undefined }), "File #11");
  });
});

describe("selection in the fragment", () => {
  it("reads and writes #item-ID and #file-ID", () => {
    assert.deepEqual(selectionFromHash("#item-12"), { kind: "item", id: "12" });
    assert.deepEqual(selectionFromHash("#file-3"), { kind: "file", id: "3" });
    assert.equal(selectionFromHash("#other"), undefined);
    assert.equal(selectionFromHash(""), undefined);
    assert.equal(hashOf({ kind: "item", id: "12" }), "#item-12");
    assert.equal(hashOf(undefined), "");
  });
});
