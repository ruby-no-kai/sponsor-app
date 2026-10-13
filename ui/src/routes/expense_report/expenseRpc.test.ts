import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import type { DescMessage, DescMethodUnary, MessageInitShape } from "@bufbuild/protobuf";
import { ExpenseFileUploadSchema } from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { adminExpenseRpc, sponsorExpenseRpc, sponsorSubmissionRpc } from "./expenseRpc.ts";
import type { Call } from "./expenseRpc.ts";

type Recorded = { service: string; method: string; input: unknown };

// Answers every call with an upload, which carries into any response a test reads one from.
function recording(): { call: Call; calls: Recorded[] } {
  const calls: Recorded[] = [];
  const call = (async <I extends DescMessage, O extends DescMessage>(
    method: DescMethodUnary<I, O>,
    input: MessageInitShape<I>,
  ) => {
    calls.push({ service: method.parent.name, method: method.name, input });
    return {
      upload: create(ExpenseFileUploadSchema, { fileId: "7" }),
      report: { id: "1" },
    };
  }) as unknown as Call;
  return { call, calls };
}

const input = { title: "Venue", amount: "100", taxAmount: "0" };

describe("adminExpenseRpc", () => {
  it("calls the AdminService for the sponsorship, whatever the operation", async () => {
    const { call, calls } = recording();
    const rpc = adminExpenseRpc({ conferenceSlug: "rubykaigi2048", sponsorshipId: 5n }, call);

    await rpc.readReport();
    await rpc.createLineItem(input);
    await rpc.updateLineItem("3", input);
    await rpc.deleteLineItem("3");
    await rpc.createFileUpload({ filename: "a.pdf", contentType: "application/pdf" });
    await rpc.initiateFileUpdate("7");
    await rpc.completeFileUpload({ fileId: "7", versionId: "v", extension: "pdf" });
    await rpc.deleteFile("7");

    const target = { conferenceSlug: "rubykaigi2048", sponsorshipId: 5n };
    assert.deepEqual(
      calls.map((c) => [c.service, c.method]),
      [
        ["AdminService", "GetExpenseReport"],
        ["AdminService", "CreateExpenseLineItem"],
        ["AdminService", "UpdateExpenseLineItem"],
        ["AdminService", "DeleteExpenseLineItem"],
        ["AdminService", "CreateExpenseFileUpload"],
        ["AdminService", "InitiateExpenseFileUpdate"],
        ["AdminService", "CompleteExpenseFileUpload"],
        ["AdminService", "DeleteExpenseFile"],
      ],
    );
    assert.deepEqual(calls[2]?.input, { ...target, lineItemId: "3", input });
    assert.deepEqual(calls[6]?.input, { ...target, fileId: "7", versionId: "v", extension: "pdf" });
  });
});

describe("sponsorExpenseRpc", () => {
  it("calls the SponsorService, naming the conference only", async () => {
    const { call, calls } = recording();
    const rpc = sponsorExpenseRpc("rubykaigi2048", call);

    await rpc.readReport();
    await rpc.createLineItem(input);
    await rpc.updateLineItem("3", input);
    await rpc.deleteLineItem("3");
    await rpc.createFileUpload({ filename: "a.pdf", contentType: "application/pdf" });
    await rpc.initiateFileUpdate("7");
    await rpc.completeFileUpload({ fileId: "7", versionId: "v", extension: "pdf" });
    await rpc.deleteFile("7");

    assert.deepEqual(
      calls.map((c) => [c.service, c.method]),
      [
        ["SponsorService", "GetExpenseReport"],
        ["SponsorService", "CreateExpenseLineItem"],
        ["SponsorService", "UpdateExpenseLineItem"],
        ["SponsorService", "DeleteExpenseLineItem"],
        ["SponsorService", "CreateExpenseFileUpload"],
        ["SponsorService", "InitiateExpenseFileUpdate"],
        ["SponsorService", "CompleteExpenseFileUpload"],
        ["SponsorService", "DeleteExpenseFile"],
      ],
    );
    assert.deepEqual(calls[0]?.input, { conferenceSlug: "rubykaigi2048" });
    assert.deepEqual(calls[2]?.input, { conferenceSlug: "rubykaigi2048", lineItemId: "3", input });
    assert.deepEqual(calls[4]?.input, {
      conferenceSlug: "rubykaigi2048",
      input: { filename: "a.pdf", contentType: "application/pdf" },
    });
  });

  it("answers the upload the server returned, and refuses an answer without one", async () => {
    const { call } = recording();
    assert.equal(
      (await sponsorExpenseRpc("c", call).createFileUpload({ filename: "a", contentType: "b" }))
        .fileId,
      "7",
    );

    const empty = (async () => ({})) as unknown as Call;
    await assert.rejects(
      sponsorExpenseRpc("c", empty).initiateFileUpdate("7"),
      /returned no upload/,
    );
  });
});

describe("sponsorSubmissionRpc", () => {
  it("submits and withdraws through the SponsorService", async () => {
    const { call, calls } = recording();
    const submission = sponsorSubmissionRpc("rubykaigi2048", call);

    assert.equal((await submission.submit())?.id, "1");
    await submission.withdraw();

    assert.deepEqual(
      calls.map((c) => [c.service, c.method, c.input]),
      [
        ["SponsorService", "SubmitExpenseReport", { conferenceSlug: "rubykaigi2048" }],
        ["SponsorService", "WithdrawExpenseReportSubmission", { conferenceSlug: "rubykaigi2048" }],
      ],
    );
  });
});
