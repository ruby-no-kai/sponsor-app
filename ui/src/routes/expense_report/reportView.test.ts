import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import {
  ExpenseReportReviewSchema,
  ExpenseReportReview_Action,
  ExpenseReportSchema,
  ExpenseReport_Status,
} from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { ADMIN_EDITOR_TEXT } from "./adminText.ts";
import {
  fileName,
  groupLineItems,
  hashOf,
  isReadOnly,
  selectionFromHash,
  submissionChecks,
  unlinkedFiles,
  verdictOf,
} from "./reportView.ts";

describe("verdictOf", () => {
  const approve = create(ExpenseReportReviewSchema, { action: ExpenseReportReview_Action.APPROVE });
  const reject = create(ExpenseReportReviewSchema, {
    action: ExpenseReportReview_Action.REJECT,
    comment: "Attach the invoice",
  });

  it("is the latest review while the report stands as it left", () => {
    assert.deepEqual(verdictOf({ status: ExpenseReport_Status.APPROVED, latestReview: approve }), {
      kind: "approved",
      at: undefined,
    });
    assert.deepEqual(verdictOf({ status: ExpenseReport_Status.REJECTED, latestReview: reject }), {
      kind: "rejected",
      comment: "Attach the invoice",
    });
  });

  it("is none once the report has moved on", () => {
    assert.equal(
      verdictOf({ status: ExpenseReport_Status.DRAFT, latestReview: reject }),
      undefined,
    );
    assert.equal(
      verdictOf({ status: ExpenseReport_Status.SUBMITTED, latestReview: approve }),
      undefined,
    );
    assert.equal(verdictOf({ status: ExpenseReport_Status.APPROVED }), undefined);
  });
});

describe("isReadOnly", () => {
  it("holds for an approved report, whoever edits", () => {
    assert.ok(isReadOnly({ status: ExpenseReport_Status.APPROVED }, "admin"));
    assert.ok(isReadOnly({ status: ExpenseReport_Status.APPROVED }, "sponsor"));
    assert.ok(!isReadOnly({ status: ExpenseReport_Status.REJECTED }, "admin"));
    assert.ok(!isReadOnly({ status: ExpenseReport_Status.REJECTED }, "sponsor"));
  });

  it("holds for a submitted report when a sponsor edits, not staff", () => {
    assert.ok(isReadOnly({ status: ExpenseReport_Status.SUBMITTED }, "sponsor"));
    assert.ok(!isReadOnly({ status: ExpenseReport_Status.SUBMITTED }, "admin"));
    assert.ok(!isReadOnly({ status: ExpenseReport_Status.DRAFT }, "sponsor"));
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
      unlinkedFiles(report).map((file) => fileName(file, ADMIN_EDITOR_TEXT)),
      ["loose.pdf"],
    );
    assert.equal(fileName({ id: "11", filename: undefined }, ADMIN_EDITOR_TEXT), "File #11");
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

describe("groupLineItems", () => {
  it("groups line items attaching the same files, however ordered, by first appearance", () => {
    const report = create(ExpenseReportSchema, {
      lineItems: [
        { id: "1", fileIds: ["11", "9"] },
        { id: "2", fileIds: [] },
        { id: "3", fileIds: ["9", "11"] },
        { id: "4", fileIds: ["9"] },
        { id: "5", fileIds: [] },
      ],
    });

    const groups = groupLineItems(report.lineItems);

    assert.deepEqual(
      groups.map((group) => [group.fileIds, group.items.map((item) => item.id)]),
      [
        [
          ["9", "11"],
          ["1", "3"],
        ],
        [[], ["2", "5"]],
        [["9"], ["4"]],
      ],
    );
  });
});

describe("submissionChecks", () => {
  const report = create(ExpenseReportSchema, {
    totalAmount: "120000.0",
    lineItems: [
      { id: "1", fileIds: ["10"] },
      { id: "2", fileIds: [] },
    ],
    files: [{ id: "10" }, { id: "11" }],
  });

  it("finds a line item without files and a file no line item attaches", () => {
    const checks = submissionChecks(report, "3500000.0");

    assert.ok(checks.someWithoutFiles);
    assert.deepEqual(
      checks.unlinkedFiles.map((file) => file.id),
      ["11"],
    );
    assert.equal(checks.remaining, "3380000.0");
    assert.ok(!checks.overage);
  });

  it("warns of expenses beyond the fee", () => {
    const checks = submissionChecks(report, "100000.0");

    assert.equal(checks.remaining, "-20000.0");
    assert.ok(checks.overage);
  });

  it("finds nothing amiss in a report spending the fee exactly, with every file attached", () => {
    const tidy = create(ExpenseReportSchema, {
      totalAmount: "100.0",
      lineItems: [{ id: "1", fileIds: ["10"] }],
      files: [{ id: "10" }],
    });

    const checks = submissionChecks(tidy, "100");

    assert.ok(!checks.overage);
    assert.ok(!checks.someWithoutFiles);
    assert.deepEqual(checks.unlinkedFiles, []);
  });
});
