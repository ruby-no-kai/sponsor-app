import type {
  DescMessage,
  DescMethodUnary,
  MessageInitShape,
  MessageShape,
} from "@bufbuild/protobuf";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import type {
  ExpenseFileUpload,
  ExpenseLineItem,
  ExpenseReport,
} from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { callRpc } from "../../lib/rpc.ts";
import type { LineItemInputInit } from "./lineItemForm.ts";

// What an RPC call takes, as callRpc does. Tests pass a recording one.
export type Call = <I extends DescMessage, O extends DescMessage>(
  method: DescMethodUnary<I, O>,
  input: MessageInitShape<I>,
) => Promise<MessageShape<O>>;

export type LineItemChange = { lineItem?: ExpenseLineItem; report?: ExpenseReport };

export type UploadCompletion = { fileId: string; versionId: string; extension: string };

// The RPCs the editor makes, whichever service it speaks to. Each is the same operation on the
// AdminService for one sponsorship, or on the SponsorService for the signed-in sponsor's own.
export type ExpenseRpc = {
  readReport(): Promise<ExpenseReport | undefined>;
  createLineItem(input: LineItemInputInit): Promise<LineItemChange>;
  updateLineItem(lineItemId: string, input: LineItemInputInit): Promise<LineItemChange>;
  deleteLineItem(lineItemId: string): Promise<ExpenseReport | undefined>;
  createFileUpload(input: { filename: string; contentType: string }): Promise<ExpenseFileUpload>;
  initiateFileUpdate(fileId: string): Promise<ExpenseFileUpload>;
  completeFileUpload(completion: UploadCompletion): Promise<void>;
  deleteFile(fileId: string): Promise<void>;
};

// The sponsor's own submission of the report, which staff review instead.
export type SubmissionRpc = {
  submit(): Promise<ExpenseReport | undefined>;
  withdraw(): Promise<ExpenseReport | undefined>;
};

export type AdminTarget = { conferenceSlug: string; sponsorshipId: bigint };

function uploadOf(response: { upload?: ExpenseFileUpload }): ExpenseFileUpload {
  if (response.upload === undefined) throw new Error("The server returned no upload");
  return response.upload;
}

export function adminExpenseRpc(target: AdminTarget, call: Call = callRpc): ExpenseRpc {
  return {
    async readReport() {
      return (await call(AdminService.method.getExpenseReport, target)).report;
    },
    createLineItem: (input) =>
      call(AdminService.method.createExpenseLineItem, { ...target, input }),
    updateLineItem: (lineItemId, input) =>
      call(AdminService.method.updateExpenseLineItem, { ...target, lineItemId, input }),
    async deleteLineItem(lineItemId) {
      return (await call(AdminService.method.deleteExpenseLineItem, { ...target, lineItemId }))
        .report;
    },
    async createFileUpload(input) {
      return uploadOf(
        await call(AdminService.method.createExpenseFileUpload, { ...target, input }),
      );
    },
    async initiateFileUpdate(fileId) {
      return uploadOf(
        await call(AdminService.method.initiateExpenseFileUpdate, { ...target, fileId }),
      );
    },
    async completeFileUpload(completion) {
      await call(AdminService.method.completeExpenseFileUpload, { ...target, ...completion });
    },
    async deleteFile(fileId) {
      await call(AdminService.method.deleteExpenseFile, { ...target, fileId });
    },
  };
}

export function sponsorExpenseRpc(conferenceSlug: string, call: Call = callRpc): ExpenseRpc {
  const target = { conferenceSlug };
  return {
    async readReport() {
      return (await call(SponsorService.method.getExpenseReport, target)).report;
    },
    createLineItem: (input) =>
      call(SponsorService.method.createExpenseLineItem, { ...target, input }),
    updateLineItem: (lineItemId, input) =>
      call(SponsorService.method.updateExpenseLineItem, { ...target, lineItemId, input }),
    async deleteLineItem(lineItemId) {
      return (await call(SponsorService.method.deleteExpenseLineItem, { ...target, lineItemId }))
        .report;
    },
    async createFileUpload(input) {
      return uploadOf(
        await call(SponsorService.method.createExpenseFileUpload, { ...target, input }),
      );
    },
    async initiateFileUpdate(fileId) {
      return uploadOf(
        await call(SponsorService.method.initiateExpenseFileUpdate, { ...target, fileId }),
      );
    },
    async completeFileUpload(completion) {
      await call(SponsorService.method.completeExpenseFileUpload, { ...target, ...completion });
    },
    async deleteFile(fileId) {
      await call(SponsorService.method.deleteExpenseFile, { ...target, fileId });
    },
  };
}

export function sponsorSubmissionRpc(conferenceSlug: string, call: Call = callRpc): SubmissionRpc {
  const target = { conferenceSlug };
  return {
    async submit() {
      return (await call(SponsorService.method.submitExpenseReport, target)).report;
    },
    async withdraw() {
      return (await call(SponsorService.method.withdrawExpenseReportSubmission, target)).report;
    },
  };
}
