import { Loader } from "@cloudflare/kumo";
import { useMemo } from "react";
import { generatePath, useParams } from "react-router";
import { useSWRConfig } from "swr";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import type { AdminServiceGetExpenseReportResponse } from "../../gen/rubykaigi/sponsor_app/admin_expense_reports_pb.ts";
import { ExpenseReport_Status } from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type { ExpenseReport } from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { idFromParam } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { isRpcKeyOf, useRpc } from "../../lib/rpc.ts";
import { notifyError } from "../../lib/toast.ts";
import { adminExpenseRpc } from "../expense_report/expenseRpc.ts";
import type { AdminTarget } from "../expense_report/expenseRpc.ts";
import { ADMIN_EDITOR_TEXT } from "../expense_report/adminText.ts";
import { useEditor } from "../expense_report/EditorContext.ts";
import { ExpenseReportEditor } from "../expense_report/ExpenseReportEditor.tsx";
import { ReviewForm } from "../expense_report/ReviewForm.tsx";
import { paths } from "../paths.ts";
import { NotFound } from "../RouteError.tsx";
import { useConferenceTitle } from "./conferenceTitle.ts";

// A sponsorship's expense report as staff see it: every report but an approved one editable, and
// a submitted one open to review.
export default function AdminExpenseReport() {
  const { slug = "", id = "" } = useParams();
  const sponsorshipId = idFromParam(id);
  if (sponsorshipId === undefined) return <NotFound />;
  return <Report key={id} slug={slug} id={id} sponsorshipId={sponsorshipId} />;
}

function Report({ slug, id, sponsorshipId }: { slug: string; id: string; sponsorshipId: bigint }) {
  const { mutate } = useSWRConfig();
  const target = useMemo<AdminTarget>(
    () => ({ conferenceSlug: slug, sponsorshipId }),
    [slug, sponsorshipId],
  );
  const rpc = useMemo(() => adminExpenseRpc(target), [target]);
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
  const sponsorshipText = sponsorshipId.toString();
  const sponsorshipName = response.sponsorship?.name ?? sponsorshipText;

  function onReport(next: ExpenseReport) {
    void reportQuery.mutate(
      (current: AdminServiceGetExpenseReportResponse | undefined) =>
        current && { ...current, report: next },
      { revalidate: false },
    );
    void mutate(
      (key) =>
        isRpcKeyOf(key, AdminService.method.listExpenseReports) ||
        isRpcKeyOf(key, AdminService.method.getSponsorship),
    );
  }

  return (
    <ExpenseReportEditor
      role="admin"
      rpc={rpc}
      text={ADMIN_EDITOR_TEXT}
      notify={notifyError}
      report={response.report}
      calculation={calculation}
      onReport={onReport}
      onRefresh={async () => {
        await reportQuery.mutate();
      }}
      fileUrl={(fileId) =>
        `/admin/conferences/${encodeURIComponent(slug)}/sponsorships/${sponsorshipText}/expense_files/${fileId}`
      }
      header={
        <PageHeader
          crumbs={[
            { label: conferenceName, href: generatePath(paths.conference, { slug }) },
            { label: "Expense reports", href: generatePath(paths.expenseReports, { slug }) },
            {
              label: sponsorshipName,
              href: generatePath(paths.sponsorship, { slug, id: sponsorshipText }),
            },
          ]}
          title="Expense report"
        />
      }
      actions={<ReviewActions target={target} />}
    />
  );
}

// Staff review a report once it has been submitted, and may replace a verdict already given.
function ReviewActions({ target }: { target: AdminTarget }) {
  const { report } = useEditor();
  return report.status === ExpenseReport_Status.DRAFT ? null : <ReviewForm target={target} />;
}
