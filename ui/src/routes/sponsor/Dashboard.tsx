import { Badge, ClipboardText, LayerCard, Link, LinkButton, Loader, Text } from "@cloudflare/kumo";
import type { ReactNode } from "react";
import { useEffect } from "react";
import { useLocation, useParams } from "react-router";
import type { Conference } from "../../gen/rubykaigi/sponsor_app/conference_pb.ts";
import type { ExpenseReportSummary } from "../../gen/rubykaigi/sponsor_app/expense_report_summary_pb.ts";
import type {
  SponsorServiceGetSponsorshipResponse,
  SponsorServiceGetSponsorshipResponse_SponsorEvents,
  SponsorServiceGetSponsorshipResponse_Tickets,
} from "../../gen/rubykaigi/sponsor_app/sponsor_shell_pb.ts";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import type { Sponsorship } from "../../gen/rubykaigi/sponsor_app/sponsorship_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { formatVenueDate } from "../../lib/dates.ts";
import { formatAmount, isWebUrl } from "../../lib/display.ts";
import { Disclosure } from "../../lib/Disclosure.tsx";
import { useT } from "../../lib/i18n.tsx";
import { useGoTo } from "../../lib/navigation.ts";
import { useRpc } from "../../lib/rpc.ts";
import { SandboxedHtml } from "../../lib/SandboxedHtml.tsx";
import { useDocumentTitle } from "../../lib/title.ts";
import {
  boothSummaryKey,
  discountCodeKey,
  eventStatusLabel,
  expenseReportStatusLabel,
  splitAnnouncements,
  todoItems,
} from "./dashboardView.ts";
import type { TodoItem } from "./dashboardView.ts";
import { CreateExpenseReportButton } from "./CreateExpenseReportButton.tsx";
import { dashboardPath, dashboardRedirect, expenseReportPath } from "./shellRedirects.ts";

export default function Dashboard() {
  const { slug = "" } = useParams();
  const { search } = useLocation();
  const t = useT();
  const goTo = useGoTo();
  // GetSponsorship would answer an applicant `unauthenticated`, which sends the browser to
  // sign in, so the viewer decides first whether this conference has a dashboard for them.
  const viewer = useRpc(SponsorService.method.getViewer, {});
  const redirect = viewer.data?.viewer && dashboardRedirect(viewer.data.viewer, slug, search);
  const sponsoring = viewer.data?.viewer !== undefined && redirect === undefined;
  const { data, error } = useRpc(
    SponsorService.method.getSponsorship,
    sponsoring ? { conferenceSlug: slug } : null,
  );
  useDocumentTitle(t("sponsorships.show.title"), data?.conference?.name);

  useEffect(() => {
    if (redirect !== undefined) goTo(redirect, { replace: true });
  }, [redirect, goTo]);

  if (viewer.error !== undefined && viewer.data === undefined) throw viewer.error;
  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const { conference, sponsorship } = data;
  if (conference === undefined || sponsorship === undefined) {
    throw new Error("GetSponsorship returned no sponsorship");
  }

  const base = dashboardPath(slug);
  const todo = todoItems(
    {
      amendmentOpen: data.amendmentOpen,
      sponsorship,
      hasExhibition: data.exhibition !== undefined,
      expenseReport: data.expenseReport,
      events: data.sponsorEvents?.events ?? [],
    },
    { base, expenseReport: expenseReportPath(slug) },
  );

  return (
    <div className="flex flex-col gap-6">
      <Text variant="heading" size="lg" as="h1">
        {t("sponsorships.show.header", { name: conference.name })}
      </Text>

      <TodoList items={todo} />

      <div className="-mb-4 md:columns-2 md:gap-4">
        <Tile>
          <PlanCard sponsorship={sponsorship} />
        </Tile>
        {data.tickets !== undefined && (
          <Tile>
            <TicketsCard
              tickets={data.tickets}
              href={data.ticketsOnTito ? `${base}/pass_redemptions` : undefined}
            />
          </Tile>
        )}
        <Tile>
          <ApplicationCard
            sponsorship={sponsorship}
            conference={conference}
            amendmentOpen={data.amendmentOpen}
            editHref={`${base}/edit`}
          />
        </Tile>
        {sponsorship.boothAssigned && (
          <Tile>
            <BoothCard data={data} base={base} />
          </Tile>
        )}
        {data.sponsorEvents !== undefined && (
          <Tile>
            <EventsCard
              sponsorEvents={data.sponsorEvents}
              submissionOpen={data.eventSubmissionOpen}
              base={base}
            />
          </Tile>
        )}
        {sponsorship.customized && (
          <Tile>
            <ExpenseReportCard
              report={data.expenseReport}
              slug={slug}
              href={expenseReportPath(slug)}
            />
          </Tile>
        )}
      </div>

      {data.announcements.length > 0 && <Announcements data={data} />}

      <div className="-mb-4 md:columns-2 md:gap-4">
        <Tile>
          <Card title={t("sponsor_ui.dashboard.broadcasts.title")}>
            <Text>{t("sponsorships.show.broadcasts.description")}</Text>
            <div>
              <LinkButton href={`${base}/broadcasts`} variant="secondary" size="sm">
                {t("sponsor_ui.dashboard.broadcasts.view_all")}
              </LinkButton>
            </div>
          </Card>
        </Tile>
        <Tile>
          <Card title={t("sponsorships.show.contact")}>
            <Text>{t("sponsorships.show.contact_help")}</Text>
            <Link href={`mailto:${conference.contactEmailAddress}`} className="break-all">
              {conference.contactEmailAddress}
            </Link>
          </Card>
        </Tile>
      </div>
    </div>
  );
}

// Keeps a card whole when its column breaks, and spaces it from the next.
function Tile({ children }: { children: ReactNode }) {
  return <div className="mb-4 break-inside-avoid">{children}</div>;
}

// What is left to do, one row each, hidden when nothing is.
function TodoList({ items }: { items: TodoItem[] }) {
  const t = useT();
  if (items.length === 0) return null;
  return (
    <Card title={t("sponsor_ui.dashboard.todo.title")}>
      <ul className="flex flex-col divide-y divide-kumo-line">
        {items.map((item) => (
          <li
            key={item.id}
            className="flex flex-col gap-2 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-center sm:justify-between sm:gap-4"
          >
            <Text>{t(item.key, item.vars)}</Text>
            {item.action !== undefined && (
              <LinkButton
                href={item.action.href}
                variant="primary"
                size="sm"
                className="self-start"
              >
                {t(item.action.key)}
              </LinkButton>
            )}
          </li>
        ))}
      </ul>
    </Card>
  );
}

function Card({ title, children }: { title: string; children: ReactNode }) {
  return (
    <LayerCard>
      <LayerCard.Secondary>{title}</LayerCard.Secondary>
      <LayerCard.Primary className="flex flex-col gap-3">{children}</LayerCard.Primary>
    </LayerCard>
  );
}

function ApplicationCard({
  sponsorship,
  conference,
  amendmentOpen,
  editHref,
}: {
  sponsorship: Sponsorship;
  conference: Conference;
  amendmentOpen: boolean;
  editHref: string;
}) {
  const t = useT();
  return (
    <Card title={t("sponsorships.show.your_application")}>
      <Text variant="heading" as="h2">
        {sponsorship.name}
      </Text>
      {isWebUrl(sponsorship.url) ? (
        <Link href={sponsorship.url} target="_blank" rel="noreferrer" className="break-all">
          {sponsorship.url}
        </Link>
      ) : (
        <Text variant="mono">{sponsorship.url}</Text>
      )}
      <Text>
        <span className="whitespace-pre-wrap">{sponsorship.profile}</span>
      </Text>
      {amendmentOpen && (
        <div className="flex flex-col items-start gap-2">
          <LinkButton href={editHref} variant="primary">
            {t("sponsor_ui.dashboard.edit_application")}
          </LinkButton>
          {conference.amendmentClosesAt !== undefined && (
            <Text variant="secondary" size="sm">
              {t("sponsorships.show.amendment_availability", {
                ts: t.dateTime(conference.amendmentClosesAt),
              })}
            </Text>
          )}
        </div>
      )}
    </Card>
  );
}

function BoothCard({ data, base }: { data: SponsorServiceGetSponsorshipResponse; base: string }) {
  const t = useT();
  const { exhibition } = data;
  return (
    <Card title={t("sponsor_ui.dashboard.booth.title")}>
      {exhibition === undefined ? (
        <>
          <div>
            <Badge variant="error">{t("sponsor_ui.dashboard.booth.not_submitted")}</Badge>
          </div>
          <div>
            <LinkButton href={`${base}/exhibition/new`} variant="primary">
              {t("sponsor_ui.dashboard.booth.send")}
            </LinkButton>
          </div>
        </>
      ) : (
        <>
          <Text>
            <span className="whitespace-pre-wrap">{exhibition.description}</span>
          </Text>
          <div>
            <LinkButton href={`${base}/exhibition/edit`} variant="secondary">
              {t("sponsor_ui.dashboard.booth.edit")}
            </LinkButton>
          </div>
        </>
      )}
    </Card>
  );
}

function EventsCard({
  sponsorEvents,
  submissionOpen,
  base,
}: {
  sponsorEvents: SponsorServiceGetSponsorshipResponse_SponsorEvents;
  submissionOpen: boolean;
  base: string;
}) {
  const t = useT();
  return (
    <Card title={t("sponsor_ui.dashboard.events.title")}>
      {sponsorEvents.events.length === 0 ? (
        <Text variant="secondary">{t("sponsorships.show.events.no_events")}</Text>
      ) : (
        <ul className="flex flex-col gap-2">
          {sponsorEvents.events.map((event) => {
            const status = eventStatusLabel(event.status);
            return (
              <li key={event.id.toString()} className="flex flex-col gap-0.5">
                <span className="flex flex-wrap items-center gap-2">
                  <Link href={`${base}/events/${event.id}`}>{event.title}</Link>
                  <Badge variant={status.tone}>{t(status.key)}</Badge>
                </span>
                {event.startsAt !== undefined && (
                  <Text variant="secondary" size="sm">
                    {formatVenueDate(event.startsAt)}
                  </Text>
                )}
              </li>
            );
          })}
        </ul>
      )}
      {submissionOpen && (
        <div>
          <LinkButton href={`${base}/events/new`} variant="primary" size="sm">
            {t("sponsor_ui.dashboard.events.submit_new")}
          </LinkButton>
        </div>
      )}
    </Card>
  );
}

function PlanCard({ sponsorship }: { sponsorship: Sponsorship }) {
  const t = useT();
  const booth = boothSummaryKey(sponsorship);
  const accepted = sponsorship.state === SponsorshipState.ACTIVE;
  return (
    <Card title={t("sponsorships.show.your_sponsorship_plan")}>
      {sponsorship.planName === undefined ? (
        <>
          <Text variant="heading" as="h2">
            {t("sponsorships.show.undetermined_plan")}
          </Text>
          <Text>{t("sponsorships.show.undetermined_plan_help")}</Text>
        </>
      ) : (
        <>
          <div className="flex flex-wrap items-center gap-2">
            <Text variant="heading" as="h2">
              {sponsorship.planName}
            </Text>
            <Badge variant={accepted ? "info" : "error"}>
              {accepted ? t("sponsor_ui.dashboard.confirmed") : t("sponsorships.show.pending")}
            </Badge>
          </div>
          {sponsorship.customized && (
            <Text>
              {t("sponsorships.show.customized_plan")} ({sponsorship.customizationName})
            </Text>
          )}
          {sponsorship.sponsorTalk && <Text>{t("sponsorships.show.sponsor_talk_eligible")}</Text>}
          {booth !== undefined && <Text>{t(booth)}</Text>}
        </>
      )}
      {sponsorship.planName === undefined && (
        <div>
          <Badge variant={accepted ? "info" : "error"}>
            {accepted ? t("sponsor_ui.dashboard.confirmed") : t("sponsorships.show.pending")}
          </Badge>
        </div>
      )}
      {!accepted && (
        <Text variant="secondary" size="sm">
          {t("sponsorships.show.pending_help")}
        </Text>
      )}
    </Card>
  );
}

function ExpenseReportCard({
  report,
  slug,
  href,
}: {
  report: ExpenseReportSummary | undefined;
  slug: string;
  href: string;
}) {
  const t = useT();
  if (report === undefined) {
    return (
      <Card title={t("sponsorships.show.expense_report.title")}>
        <Text variant="secondary">{t("sponsor_ui.shell.expense_report_not_created")}</Text>
        <div>
          <CreateExpenseReportButton slug={slug} />
        </div>
      </Card>
    );
  }

  const status = expenseReportStatusLabel(report.status);
  const overspent = report.remaining?.startsWith("-") ?? false;
  return (
    <Card title={t("sponsorships.show.expense_report.title")}>
      <div>
        <Badge variant={status.tone}>{t(status.key)}</Badge>
      </div>
      <dl className="grid grid-cols-[1fr_max-content] gap-x-3 gap-y-1">
        {report.fee !== undefined && (
          <Amount label={t("sponsorships.show.expense_report.fee")}>
            {formatAmount(report.fee)}
          </Amount>
        )}
        <Amount label={t("sponsorships.show.expense_report.total_expense")}>
          {formatAmount(report.totalAmount)}
        </Amount>
        {report.remaining !== undefined && (
          <Amount label={t("sponsorships.show.expense_report.remaining")}>
            <Text variant={overspent ? "error" : "body"}>{formatAmount(report.remaining)}</Text>
          </Amount>
        )}
      </dl>
      <div>
        <LinkButton href={href} variant="primary" size="sm">
          {t("sponsor_ui.dashboard.expense_report.open")}
        </LinkButton>
      </div>
    </Card>
  );
}

function Amount({ label, children }: { label: string; children: ReactNode }) {
  return (
    <>
      <dt>
        <Text variant="secondary" size="sm">
          {label}
        </Text>
      </dt>
      <dd className="text-right tabular-nums">{children}</dd>
    </>
  );
}

function TicketsCard({
  tickets,
  href,
}: {
  tickets: SponsorServiceGetSponsorshipResponse_Tickets;
  // The page listing registrations, which exists only where tickets go through Ti.to.
  href: string | undefined;
}) {
  const t = useT();
  const hasCodes = tickets.discountCodes.length > 0;
  return (
    <Card title={t("sponsor_ui.dashboard.tickets.title")}>
      {tickets.discountCodes.map((code) => (
        <div key={code.kind} className="flex flex-col gap-1.5">
          <Text>
            <strong>{t(discountCodeKey(code.kind))}</strong>
            {code.quantity !== undefined && (
              <> ({t("sponsorships.show.tickets.quantity", { count: code.quantity })})</>
            )}
          </Text>
          <ClipboardText
            text={code.url}
            size="base"
            className="max-w-full"
            labels={{ copyAction: t("sponsor_ui.dashboard.tickets.copy") }}
          />
        </div>
      ))}
      {hasCodes && (
        <Disclosure label={t("sponsor_ui.dashboard.tickets.about")}>
          <ul className="list-disc pl-5">
            <li>
              <Text size="sm">{t("sponsorships.show.tickets.help.requirement")}</Text>
            </li>
            <li>
              <Text size="sm">{t("sponsorships.show.tickets.help.unique")}</Text>
            </li>
          </ul>
        </Disclosure>
      )}
      {href !== undefined && (
        <div>
          <LinkButton href={href} variant="secondary" size="sm">
            {t("sponsor_ui.dashboard.tickets.view_passes")}
          </LinkButton>
        </div>
      )}
    </Card>
  );
}

function Announcements({ data }: { data: SponsorServiceGetSponsorshipResponse }) {
  const t = useT();
  const [newest, older] = splitAnnouncements(data.announcements);
  return (
    <Card title={t("sponsorships.show.announcements")}>
      <AnnouncementList announcements={newest} />
      {older.length > 0 && (
        <Disclosure label={t("sponsor_ui.dashboard.older_announcements", { count: older.length })}>
          <AnnouncementList announcements={older} />
        </Disclosure>
      )}
    </Card>
  );
}

function AnnouncementList({
  announcements,
}: {
  announcements: SponsorServiceGetSponsorshipResponse["announcements"];
}) {
  const t = useT();
  return (
    <ul className="flex flex-col divide-y divide-kumo-line">
      {announcements.map((announcement) => {
        const anchor = `announcement-${announcement.issue}`;
        return (
          <li key={announcement.issue} className="flex flex-col gap-2 py-3 first:pt-0 last:pb-0">
            <Text variant="heading" as="h3">
              <span id={anchor}>{announcement.title}</span>
            </Text>
            <SandboxedHtml html={announcement.bodyHtml} title={announcement.title} />
            {announcement.publishedAt !== undefined && (
              <a href={`#${anchor}`} className="self-end text-sm text-kumo-subtle">
                {t.dateTime(announcement.publishedAt)}
              </a>
            )}
          </li>
        );
      })}
    </ul>
  );
}
