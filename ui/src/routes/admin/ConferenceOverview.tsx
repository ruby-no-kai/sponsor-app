import { Badge, Empty, LayerCard, Link, LinkButton, Loader, Text } from "@cloudflare/kumo";
import { ArrowSquareOutIcon, HandshakeIcon, PencilSimpleIcon } from "@phosphor-icons/react";
import type { ReactNode } from "react";
import { generatePath, useParams } from "react-router";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import type { SponsorshipSummary } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { formatDateRange } from "../../lib/dates.ts";
import { formatTimestamp } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { paths } from "../paths.ts";
import { groupCounts, groupSponsorships } from "./sponsorshipGroups.ts";

export default function ConferenceOverview() {
  const { slug = "" } = useParams();
  const { data, error } = useRpc(AdminService.method.getConference, { conferenceSlug: slug });
  const viewer = useRpc(AdminService.method.getViewer, {}).data?.staff;
  useDocumentTitle(data?.conference?.conference?.name ?? slug);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;

  const adminConference = data.conference;
  const conference = adminConference?.conference;
  if (adminConference === undefined || conference === undefined)
    throw new Error("GetConference returned no conference");

  const base = `/admin/conferences/${encodeURIComponent(conference.slug)}`;
  const { groups, withdrawn } = groupSponsorships(data.plans, data.sponsorships);

  const sponsorshipGroups = (
    <>
      {groups.map((group) => (
        <Card
          key={group.key}
          title={
            <span className="flex items-baseline justify-between gap-2">
              <span>
                {group.plan?.name ??
                  (group.planId === undefined ? "Undetermined" : `Plan ${group.planId}`)}
              </span>
              <Text variant="secondary" size="sm" as="span">
                {groupCounts(group)}
              </Text>
            </span>
          }
        >
          <Rows>
            {group.sponsorships.map((sponsorship) => (
              <Row key={sponsorship.id.toString()}>
                <span className="min-w-0 break-words">
                  <SponsorshipName base={base} sponsorship={sponsorship} />
                </span>
                <SponsorshipBadges sponsorship={sponsorship} />
              </Row>
            ))}
          </Rows>
        </Card>
      ))}
      {withdrawn.length > 0 && (
        <Card title="Withdrawn">
          <Rows>
            {withdrawn.map((sponsorship) => (
              <Row key={sponsorship.id.toString()}>
                <span className="min-w-0 break-words text-kumo-subtle">
                  <SponsorshipName base={base} sponsorship={sponsorship} />
                </span>
              </Row>
            ))}
          </Rows>
        </Card>
      )}
    </>
  );

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        title={conference.name}
        subtitle={<Text variant="mono">{conference.slug}</Text>}
        actions={
          <>
            {viewer !== undefined && !viewer.restricted && (
              <LinkButton
                href={generatePath(paths.conferenceEdit, { slug: conference.slug })}
                variant="primary"
                icon={PencilSimpleIcon}
              >
                Edit
              </LinkButton>
            )}
            <LinkButton
              href={adminConference.applicationFormUrl}
              variant="secondary"
              icon={ArrowSquareOutIcon}
              external
            >
              Preview
            </LinkButton>
          </>
        }
      />

      <div className="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_20rem]">
        <div className="flex flex-col gap-4">
          <Text variant="heading" as="h3">
            Sponsorships
          </Text>
          {data.sponsorships.length === 0 ? (
            <Empty
              size="sm"
              icon={<HandshakeIcon size={32} />}
              title="No sponsorships"
              description="No sponsor has applied yet."
            />
          ) : (
            sponsorshipGroups
          )}
        </div>

        <div className="flex flex-col gap-4">
          <Card title="Details">
            <dl className="grid grid-cols-[max-content_1fr] gap-x-3 gap-y-1">
              <Term label="Applications open">
                {conference.applicationOpensAt === undefined
                  ? "Not scheduled"
                  : formatDateRange(conference.applicationOpensAt, conference.applicationClosesAt, {
                      from: "Not scheduled",
                      to: "no deadline",
                    })}
              </Term>
              <Term label="Amendments close">
                {formatTimestamp(conference.amendmentClosesAt, "No deadline")}
              </Term>
              {adminConference.hidden && (
                <Term label="Form URL">
                  <Link href={adminConference.applicationFormUrl} className="break-all">
                    {adminConference.applicationFormUrl}
                  </Link>
                </Term>
              )}
            </dl>
          </Card>

          <Card title="Form descriptions">
            <Rows>
              {data.formDescriptionLocales.map((locale) => (
                <Row key={locale}>
                  <Link
                    href={generatePath(paths.formDescription, { slug: conference.slug, locale })}
                  >
                    {locale}
                  </Link>
                </Row>
              ))}
              <Row>
                <Link href={generatePath(paths.formDescriptionNew, { slug: conference.slug })}>
                  Add locale
                </Link>
              </Row>
            </Rows>
          </Card>

          <Card title="Plans">
            <Rows>
              {data.plans.map((plan) => (
                <Row key={plan.id.toString()}>
                  <Link
                    href={generatePath(paths.planEdit, {
                      slug: conference.slug,
                      id: plan.id.toString(),
                    })}
                  >
                    {plan.name}
                  </Link>
                  <Text variant="secondary" as="span">
                    {plan.activeSponsorshipCount}/{plan.capacity} active
                  </Text>
                </Row>
              ))}
              <Row>
                <Link href={generatePath(paths.plans, { slug: conference.slug })}>
                  View all plans
                </Link>
                <Link href={generatePath(paths.planNew, { slug: conference.slug })}>Add plan</Link>
              </Row>
            </Rows>
          </Card>

          <Card title="Exports">
            <Rows>
              <Row>
                <Link href={`${base}/sponsors_yml`}>sponsors.yml</Link>
              </Row>
              <Row>
                <Link href={`${base}/sponsors_json`}>sponsors.json</Link>
              </Row>
              <Row>
                <Link href={`${base}/asset_urls`}>Asset URLs</Link>
                <Text variant="secondary" as="span">
                  Valid for an hour
                </Text>
              </Row>
            </Rows>
          </Card>
        </div>
      </div>
    </div>
  );
}

function Card({ title, children }: { title: ReactNode; children: ReactNode }) {
  return (
    <LayerCard>
      <LayerCard.Secondary>{title}</LayerCard.Secondary>
      <LayerCard.Primary className="flex flex-col gap-3">{children}</LayerCard.Primary>
    </LayerCard>
  );
}

function Rows({ children }: { children: ReactNode }) {
  return <ul className="-my-2 divide-y divide-kumo-line">{children}</ul>;
}

function Row({ children }: { children: ReactNode }) {
  return (
    <li className="flex flex-wrap items-center justify-between gap-x-3 gap-y-1 py-2">{children}</li>
  );
}

function Term({ label, children }: { label: string; children: ReactNode }) {
  return (
    <>
      <dt className="font-medium">{label}</dt>
      <dd className="min-w-0 break-words">{children}</dd>
    </>
  );
}

function SponsorshipName({ base, sponsorship }: { base: string; sponsorship: SponsorshipSummary }) {
  return (
    <>
      {sponsorship.customizationName !== undefined && `${sponsorship.customizationName}: `}
      <Link href={`${base}/sponsorships/${sponsorship.id}`}>{sponsorship.name}</Link>
    </>
  );
}

function SponsorshipBadges({ sponsorship }: { sponsorship: SponsorshipSummary }) {
  return (
    <span className="ml-2 inline-flex gap-1">
      {sponsorship.boothAssigned && <Badge variant="info">Booth</Badge>}
      {sponsorship.customizationPlanned && <Badge variant="warning">Custom plan: tentative</Badge>}
      {sponsorship.state !== SponsorshipState.ACTIVE && (
        <Badge variant="warning">Not accepted</Badge>
      )}
      {sponsorship.suspended && <Badge variant="error">Suspended</Badge>}
    </span>
  );
}
