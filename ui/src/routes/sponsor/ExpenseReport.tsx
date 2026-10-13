import { Empty, Loader, Text } from "@cloudflare/kumo";
import { Code, ConnectError } from "@connectrpc/connect";
import { ReceiptIcon } from "@phosphor-icons/react";
import { useMemo } from "react";
import { useParams } from "react-router";
import { useSWRConfig } from "swr";
import type { KeyedMutator } from "swr";
import type { SponsorServiceGetExpenseReportResponse } from "../../gen/rubykaigi/sponsor_app/sponsor_expense_reports_pb.ts";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import type {
  ExpenseReport as ExpenseReportMessage,
  ExpenseReportCalculation,
} from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { useT } from "../../lib/i18n.tsx";
import { isRpcKeyOf, useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { editorText } from "../expense_report/text.ts";
import { sponsorExpenseRpc, sponsorSubmissionRpc } from "../expense_report/expenseRpc.ts";
import { ExpenseReportEditor } from "../expense_report/ExpenseReportEditor.tsx";
import { SubmissionActions } from "../expense_report/SubmissionActions.tsx";
import { CreateExpenseReportButton } from "./CreateExpenseReportButton.tsx";
import { SponsorNotFound, notifyFailure } from "./SponsorRouteError.tsx";

// The sponsor's expense report: an editor for the report, or the offer to start one. Only a
// sponsorship with a confirmed custom package has either.
export default function ExpenseReport() {
  const { slug = "" } = useParams();
  const sponsorship = useRpc(SponsorService.method.getSponsorship, { conferenceSlug: slug });

  if (sponsorship.error !== undefined && sponsorship.data === undefined) throw sponsorship.error;
  if (sponsorship.data === undefined) return <Loader size="lg" />;
  if (sponsorship.data.sponsorship?.customized !== true) return <SponsorNotFound />;
  return <Screen slug={slug} conferenceName={sponsorship.data.conference?.name ?? slug} />;
}

function Screen({ slug, conferenceName }: { slug: string; conferenceName: string }) {
  const t = useT();
  const reportQuery = useRpc(SponsorService.method.getExpenseReport, { conferenceSlug: slug });
  const calculationQuery = useRpc(SponsorService.method.calculateExpenseReport, {
    conferenceSlug: slug,
  });
  useDocumentTitle(t("expense_reports.show.title"), conferenceName);

  const notStarted =
    reportQuery.error instanceof ConnectError && reportQuery.error.code === Code.NotFound;
  if (notStarted) return <NotStarted slug={slug} conferenceName={conferenceName} />;
  if (reportQuery.error !== undefined && reportQuery.data === undefined) throw reportQuery.error;
  if (calculationQuery.error !== undefined && calculationQuery.data === undefined) {
    throw calculationQuery.error;
  }
  const report = reportQuery.data?.report;
  const calculation = calculationQuery.data?.calculation;
  if (reportQuery.data === undefined || calculationQuery.data === undefined) {
    return <Loader size="lg" />;
  }
  if (report === undefined || calculation === undefined) {
    throw new Error("The server returned no expense report or calculation");
  }

  return (
    <Editor
      slug={slug}
      conferenceName={conferenceName}
      report={report}
      calculation={calculation}
      mutateReport={reportQuery.mutate}
    />
  );
}

type EditorProps = {
  slug: string;
  conferenceName: string;
  report: ExpenseReportMessage;
  calculation: ExpenseReportCalculation;
  mutateReport: KeyedMutator<SponsorServiceGetExpenseReportResponse>;
};

function Editor({ slug, conferenceName, report, calculation, mutateReport }: EditorProps) {
  const t = useT();
  const { mutate } = useSWRConfig();
  const text = useMemo(() => editorText(t), [t]);
  const rpc = useMemo(() => sponsorExpenseRpc(slug), [slug]);
  const submission = useMemo(() => sponsorSubmissionRpc(slug), [slug]);

  function onReport(next: ExpenseReportMessage) {
    void mutateReport(
      (current: SponsorServiceGetExpenseReportResponse | undefined) =>
        current && { ...current, report: next },
      { revalidate: false },
    );
    void mutate((key) => isRpcKeyOf(key, SponsorService.method.getSponsorship));
  }

  return (
    <ExpenseReportEditor
      role="sponsor"
      rpc={rpc}
      text={text}
      notify={(error) => notifyFailure(t, error)}
      report={report}
      calculation={calculation}
      onReport={onReport}
      onRefresh={async () => {
        await mutateReport();
      }}
      fileUrl={(fileId) => `/conferences/${encodeURIComponent(slug)}/expense_files/${fileId}`}
      header={
        <Text variant="heading" size="lg" as="h1">
          {t("expense_reports.show.header", { name: conferenceName })}
        </Text>
      }
      actions={<SubmissionActions submission={submission} calculation={calculation} />}
    />
  );
}

function NotStarted({ slug, conferenceName }: { slug: string; conferenceName: string }) {
  const t = useT();
  return (
    <div className="flex flex-col gap-4">
      <Text variant="heading" size="lg" as="h1">
        {t("expense_reports.show.header", { name: conferenceName })}
      </Text>
      <Empty
        icon={<ReceiptIcon size={32} />}
        title={t("sponsor_ui.shell.expense_report_not_created")}
      />
      <div className="flex justify-center">
        <CreateExpenseReportButton slug={slug} />
      </div>
    </div>
  );
}
