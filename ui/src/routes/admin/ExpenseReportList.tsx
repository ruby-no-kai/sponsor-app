import { Badge, Empty, LayerCard, Link, Loader, Table, Text } from "@cloudflare/kumo";
import { ReceiptIcon } from "@phosphor-icons/react";
import { generatePath, useParams } from "react-router";
import type { ExpenseReportTableRow } from "../../gen/rubykaigi/sponsor_app/admin_expense_reports_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { formatAmount } from "../../lib/display.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { paths } from "../paths.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";
import { EXPENSE_REPORT_STATUS_LABELS } from "./expense_report/reportView.ts";
import { labelOf } from "./sponsorshipView.ts";

export default function ExpenseReportList() {
  const { slug = "" } = useParams();
  const { data, error } = useRpc(AdminService.method.listExpenseReports, { conferenceSlug: slug });
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, "Expense reports");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[{ label: conferenceName, href: generatePath(paths.conference, { slug }) }]}
        title="Expense reports"
      />

      {data.rows.length === 0 ? (
        <Empty
          icon={<ReceiptIcon size={32} />}
          title="No custom sponsorships"
          description="Expense reports are kept for sponsorships with a confirmed custom package."
        />
      ) : (
        <>
          <LayerCard className="hidden overflow-x-auto p-0 md:block">
            <Table>
              <Table.Header>
                <Table.Row>
                  <Table.Head>Sponsor</Table.Head>
                  <Table.Head>Plan</Table.Head>
                  <Table.Head>Status</Table.Head>
                  <Table.Head className="text-right">Total (excl. tax)</Table.Head>
                  <Table.Head className="text-right">Fee</Table.Head>
                  <Table.Head className="text-right">Remaining</Table.Head>
                </Table.Row>
              </Table.Header>
              <Table.Body>
                {data.rows.map((row) => (
                  <ReportRow key={row.sponsorship?.id.toString()} slug={slug} row={row} />
                ))}
              </Table.Body>
            </Table>
          </LayerCard>
          <LayerCard className="p-0 md:hidden">
            <ul className="divide-y divide-kumo-line">
              {data.rows.map((row) => (
                <StackedRow key={row.sponsorship?.id.toString()} slug={slug} row={row} />
              ))}
            </ul>
          </LayerCard>
        </>
      )}
    </div>
  );
}

// A sponsorship's row leads to its report, or to the sponsorship while it has none.
function rowHref(slug: string, row: ExpenseReportTableRow): string | undefined {
  if (row.sponsorship === undefined) return undefined;
  const id = row.sponsorship.id.toString();
  return generatePath(row.report === undefined ? paths.sponsorship : paths.expenseReport, {
    slug,
    id,
  });
}

function StatusBadge({ report }: { report: ExpenseReportTableRow["report"] }) {
  if (report === undefined) return <Text variant="secondary">No report</Text>;
  const status = labelOf(EXPENSE_REPORT_STATUS_LABELS, report.status);
  return <Badge variant={status.tone}>{status.text}</Badge>;
}

function ReportRow({ slug, row }: { slug: string; row: ExpenseReportTableRow }) {
  const { sponsorship, report } = row;
  const href = rowHref(slug, row);
  if (sponsorship === undefined || href === undefined) return null;

  return (
    <Table.Row>
      <Table.Cell>
        <Link href={href}>{sponsorship.name}</Link>
      </Table.Cell>
      <Table.Cell>{row.displayedPlanName}</Table.Cell>
      <Table.Cell>
        <StatusBadge report={report} />
      </Table.Cell>
      <Table.Cell className="text-right font-mono">
        {report !== undefined && formatAmount(report.totalAmount)}
      </Table.Cell>
      <Table.Cell className="text-right font-mono">{formatAmount(row.totalFee)}</Table.Cell>
      <Table.Cell className="text-right font-mono">
        {report !== undefined && formatAmount(report.offset)}
      </Table.Cell>
    </Table.Row>
  );
}

function StackedRow({ slug, row }: { slug: string; row: ExpenseReportTableRow }) {
  const { sponsorship, report } = row;
  const href = rowHref(slug, row);
  if (sponsorship === undefined || href === undefined) return null;

  return (
    <li className="flex flex-col gap-1.5 px-4 py-3">
      <div className="flex flex-col">
        <Link href={href}>{sponsorship.name}</Link>
        <Text variant="secondary">{row.displayedPlanName}</Text>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-1">
        <StatusBadge report={report} />
        {report !== undefined && (
          <span>
            <span className="text-kumo-subtle">Remaining</span>{" "}
            <span className="font-mono text-[0.9em] font-medium">
              {formatAmount(report.offset)}
            </span>
          </span>
        )}
      </div>
    </li>
  );
}
