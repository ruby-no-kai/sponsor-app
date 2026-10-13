import { toJsonString } from "@bufbuild/protobuf";
import { Badge, Banner, Button, Link, Loader, Text } from "@cloudflare/kumo";
import { ArrowLeftIcon, ChatTextIcon } from "@phosphor-icons/react";
import { useRef, useState } from "react";
import type { ReactNode } from "react";
import { generatePath, useLocation, useNavigate, useParams } from "react-router";
import { useSWRConfig } from "swr";
import type { KeyedMutator } from "swr";
import type { AdminServiceGetExpenseReportResponse } from "../../../gen/rubykaigi/sponsor_app/admin_expense_reports_pb.ts";
import { AdminService } from "../../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import {
  ExpenseLineItemSchema,
  ExpenseReportReview_Action,
  ExpenseReport_Status,
} from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type {
  ExpenseReport,
  ExpenseReportCalculation,
} from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { idFromParam } from "../../../lib/forms.ts";
import { callRpc, isRpcKeyOf, useRpc } from "../../../lib/rpc.ts";
import { NotFound } from "../../RouteError.tsx";
import { paths } from "../../paths.ts";
import { useConferenceTitle } from "../conferenceTitle.ts";
import { labelOf } from "../sponsorshipView.ts";
import { formatAmountAt, subtractAmounts } from "./amounts.ts";
import { EditorProvider } from "./EditorContext.ts";
import type { Editor } from "./EditorContext.ts";
import { FileView } from "./FileView.tsx";
import { LeftPane } from "./LeftPane.tsx";
import { lineItemInputOf } from "./lineItemForm.ts";
import { LineItemForm } from "./LineItemForm.tsx";
import {
  EXPENSE_REPORT_STATUS_LABELS,
  hashOf,
  isReadOnly,
  selectionFromHash,
} from "./reportView.ts";
import type { Selection } from "./reportView.ts";
import { ReviewForm } from "./ReviewForm.tsx";
import { RightPane } from "./RightPane.tsx";
import { useIsMobile } from "./useIsMobile.ts";

export default function ExpenseReportEditor() {
  const { slug = "", id = "" } = useParams();
  const sponsorshipId = idFromParam(id);
  if (sponsorshipId === undefined) return <NotFound />;
  return <Report key={id} slug={slug} id={id} sponsorshipId={sponsorshipId} />;
}

function Report({ slug, id, sponsorshipId }: { slug: string; id: string; sponsorshipId: bigint }) {
  const target = { conferenceSlug: slug, sponsorshipId };
  const reportQuery = useRpc(AdminService.method.getExpenseReport, target);
  const calculationQuery = useRpc(AdminService.method.calculateExpenseReport, target);
  const conferenceName =
    useRpc(AdminService.method.getConference, { conferenceSlug: slug }).data?.conference?.conference
      ?.name ?? slug;
  useConferenceTitle(slug, `Expense report: ${reportQuery.data?.sponsorship?.name ?? id}`);

  for (const { data, error } of [reportQuery, calculationQuery]) {
    if (error !== undefined && data === undefined) throw error;
  }
  const response = reportQuery.data;
  const calculation = calculationQuery.data?.calculation;
  if (response === undefined || calculationQuery.data === undefined) return <Loader size="lg" />;
  if (response.report === undefined || calculation === undefined) {
    throw new Error("The server returned no expense report or calculation");
  }

  return (
    <ReportEditor
      slug={slug}
      conferenceName={conferenceName}
      target={target}
      response={response}
      report={response.report}
      calculation={calculation}
      mutateReport={reportQuery.mutate}
    />
  );
}

function ReportEditor({
  slug,
  conferenceName,
  target,
  response,
  report,
  calculation,
  mutateReport,
}: {
  slug: string;
  conferenceName: string;
  target: Editor["target"];
  response: AdminServiceGetExpenseReportResponse;
  report: ExpenseReport;
  calculation: ExpenseReportCalculation;
  mutateReport: KeyedMutator<AdminServiceGetExpenseReportResponse>;
}) {
  const isMobile = useIsMobile();
  const { mutate } = useSWRConfig();
  const location = useLocation();
  const navigate = useNavigate();
  const selection = selectionFromHash(location.hash);
  const selectedItem =
    selection?.kind === "item"
      ? report.lineItems.find((item) => item.id === selection.id)
      : undefined;
  const selectedFile =
    selection?.kind === "file" ? report.files.find((file) => file.id === selection.id) : undefined;
  const [previewFileId, setPreviewFileId] = useState<string | undefined>(() =>
    selection?.kind === "file" ? selection.id : selectedItem?.fileIds[0],
  );
  const [mobileView, setMobileView] = useState<"list" | "detail">(
    selection === undefined ? "list" : "detail",
  );
  const dirtyRef = useRef(false);
  const readOnly = isReadOnly(report);
  const sponsorshipId = target.sponsorshipId.toString();

  function select(next: Selection) {
    void navigate(
      { pathname: location.pathname, search: location.search, hash: hashOf(next) },
      { replace: true, preventScrollReset: true },
    );
  }

  // Selecting another pane drops what the line item form holds, so a person is asked first.
  function confirmLeaving(): boolean {
    return !dirtyRef.current || window.confirm("You have unsaved changes. Discard them?");
  }

  function showItem(id: string) {
    select({ kind: "item", id });
    setPreviewFileId(report.lineItems.find((item) => item.id === id)?.fileIds[0]);
    if (isMobile) setMobileView("detail");
  }

  function showFile(id: string) {
    select({ kind: "file", id });
    setPreviewFileId(id);
    if (isMobile) setMobileView("detail");
  }

  function clearSelection() {
    select(undefined);
    setPreviewFileId(undefined);
  }

  function applyReport(next: ExpenseReport | undefined) {
    if (next === undefined) return;
    void mutateReport((current) => current && { ...current, report: next }, {
      revalidate: false,
    });
    void mutate(
      (key) =>
        isRpcKeyOf(key, AdminService.method.listExpenseReports) ||
        isRpcKeyOf(key, AdminService.method.getSponsorship),
    );
  }

  const editor: Editor = {
    target,
    report,
    rounding: calculation,
    readOnly,
    isMobile,
    applyReport,
    async refreshReport() {
      await mutateReport();
    },
    async updateLineItem(lineItemId, change) {
      const { report: fresh } = await callRpc(AdminService.method.getExpenseReport, target);
      const item = fresh?.lineItems.find((candidate) => candidate.id === lineItemId);
      if (item === undefined) {
        applyReport(fresh);
        return false;
      }
      const response = await callRpc(AdminService.method.updateExpenseLineItem, {
        ...target,
        lineItemId,
        input: { ...lineItemInputOf(item), ...change(item) },
      });
      applyReport(response.report);
      return true;
    },
    fileUrl: (fileId) =>
      `/admin/conferences/${encodeURIComponent(slug)}/sponsorships/${sponsorshipId}/expense_files/${fileId}`,
  };

  const previewFile = report.files.find((file) => file.id === previewFileId);
  const review = report.latestReview;
  const status = labelOf(EXPENSE_REPORT_STATUS_LABELS, report.status);
  const remaining = subtractAmounts(calculation.totalFee, report.totalAmount);
  const sponsorshipName = response.sponsorship?.name ?? sponsorshipId;

  let center: ReactNode;
  if (selectedItem !== undefined) {
    center = (
      <LineItemForm
        key={toJsonString(ExpenseLineItemSchema, { ...selectedItem, position: 0 })}
        item={selectedItem}
        dirtyRef={dirtyRef}
        onSelectItem={showItem}
        onDeleted={clearSelection}
        onPreviewFile={setPreviewFileId}
      />
    );
  } else if (selectedFile !== undefined && !readOnly) {
    center = <FileView file={selectedFile} onSelectItem={showItem} />;
  } else {
    center = (
      <div className="flex flex-1 items-center justify-center p-4">
        <Text variant="secondary">Select a line item</Text>
      </div>
    );
  }

  return (
    <EditorProvider value={editor}>
      <div className="flex flex-col gap-4">
        <div>
          <div className="flex flex-wrap gap-x-2 text-sm">
            <Link href={generatePath(paths.conference, { slug })}>{conferenceName}</Link>
            <span aria-hidden>›</span>
            <Link href={generatePath(paths.expenseReports, { slug })}>Expense reports</Link>
            <span aria-hidden>›</span>
            <Link href={generatePath(paths.sponsorship, { slug, id: sponsorshipId })}>
              {sponsorshipName}
            </Link>
          </div>
          <Text variant="heading" size="lg" as="h2">
            Expense report: {sponsorshipName}
          </Text>
        </div>

        <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
          <Badge variant={status.tone}>{status.text}</Badge>
          <Figure label="Fee" value={formatAmountAt(calculation.totalFee, calculation.decimal)} />
          <span>
            <Figure
              label="Expense"
              value={formatAmountAt(report.totalAmount, calculation.decimal)}
            />{" "}
            <Figure
              label="+ tax"
              value={formatAmountAt(report.totalTaxAmount, calculation.decimal)}
            />
          </span>
          {remaining !== undefined && (
            <Figure
              label="Remaining"
              value={formatAmountAt(remaining, calculation.decimal)}
              className={remaining.startsWith("-") ? "text-kumo-danger" : "text-kumo-success"}
            />
          )}
        </div>

        {review?.action === ExpenseReportReview_Action.REJECT && review.comment !== undefined && (
          <Banner
            variant="error"
            icon={<ChatTextIcon />}
            title="Review feedback"
            description={<span className="whitespace-pre-wrap">{review.comment}</span>}
          />
        )}

        <div
          className={`flex overflow-hidden rounded-lg border border-kumo-line bg-kumo-base ${
            isMobile ? "min-h-[60vh] flex-col" : "h-[80vh]"
          }`}
        >
          {(!isMobile || mobileView === "list") && (
            <LeftPane
              selectedItemId={selectedItem?.id}
              selectedFileId={selection?.kind === "file" ? selection.id : undefined}
              onSelectItem={(id) => {
                if (confirmLeaving()) showItem(id);
              }}
              onSelectFile={(id) => {
                if (confirmLeaving()) showFile(id);
              }}
            />
          )}
          {(!isMobile || mobileView === "detail") && (
            <>
              {isMobile && (
                <div className="border-b border-kumo-line p-2">
                  <Button
                    variant="secondary"
                    size="sm"
                    icon={ArrowLeftIcon}
                    onClick={() => {
                      if (!confirmLeaving()) return;
                      setMobileView("list");
                      clearSelection();
                    }}
                  >
                    Back
                  </Button>
                </div>
              )}
              <div className="flex min-h-0 min-w-64 flex-[4_0_0] flex-col overflow-auto">
                {center}
              </div>
            </>
          )}
          {!isMobile && <RightPane file={previewFile} />}
        </div>

        {report.status !== ExpenseReport_Status.DRAFT && <ReviewForm />}
      </div>
    </EditorProvider>
  );
}

function Figure({
  label,
  value,
  className = "",
}: {
  label: string;
  value: string;
  className?: string;
}) {
  return (
    <span className="whitespace-nowrap">
      <span className="text-kumo-subtle">{label}</span>{" "}
      <strong className={`font-mono ${className}`}>{value}</strong>
    </span>
  );
}
