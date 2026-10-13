import { Badge, Button, LayerCard, Link, LinkButton, Loader, Text } from "@cloudflare/kumo";
import {
  ClockCounterClockwiseIcon,
  EnvelopeSimpleIcon,
  MaskHappyIcon,
  PencilSimpleIcon,
  SignOutIcon,
} from "@phosphor-icons/react";
import type { ReactNode } from "react";
import { generatePath, useParams } from "react-router";
import { useSWRConfig } from "swr";
import type {
  AdminSponsorship,
  AdminSponsorship_Contact,
} from "../../gen/rubykaigi/sponsor_app/admin_sponsorship_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { idFromParam } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { notifyError, toastManager } from "../../lib/toast.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import { ConfirmButton } from "./ConfirmButton.tsx";
import { StaffNotes } from "./StaffNotes.tsx";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";
import {
  EVENT_STATUS_LABELS,
  EXPENSE_REPORT_STATUS_LABELS,
  boothStatus,
  customizationStatus,
  formatAmount,
  isOverWordLimit,
  isWebUrl,
  labelOf,
  titoKindLabel,
  wordCountText,
} from "./sponsorshipView.ts";

export default function SponsorshipDetail() {
  const { slug = "", id = "" } = useParams();
  const sponsorshipId = idFromParam(id);
  if (sponsorshipId === undefined) return <NotFound />;
  return <Detail key={id} slug={slug} id={id} sponsorshipId={sponsorshipId} />;
}

function Detail({ slug, id, sponsorshipId }: { slug: string; id: string; sponsorshipId: bigint }) {
  const target = { conferenceSlug: slug, sponsorshipId };
  const { data, error } = useRpc(AdminService.method.getSponsorship, target);
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, data?.sponsorship?.name ?? id);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const { sponsorship } = data;
  if (sponsorship === undefined) throw new Error("GetSponsorship returned no sponsorship");

  const pathParams = { slug, id };
  const billingContact = sponsorship.alternateBillingContact ?? sponsorship.contact;
  const base = `/admin/conferences/${encodeURIComponent(slug)}`;
  const sponsorshipBase = `${base}/sponsorships/${sponsorship.id}`;

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[{ label: conferenceName, href: generatePath(paths.conference, { slug }) }]}
        title={sponsorship.name}
        actions={
          <>
            <LinkButton
              href={generatePath(paths.sponsorshipEdit, pathParams)}
              variant="primary"
              icon={PencilSimpleIcon}
            >
              Edit
            </LinkButton>
            <LinkButton
              href={generatePath(paths.sponsorshipEditingHistory, pathParams)}
              variant="secondary"
              icon={ClockCounterClockwiseIcon}
            >
              History
            </LinkButton>
            {sponsorship.contact !== undefined && (
              <LinkButton
                href={sponsorship.contact.composeEmailUrl}
                variant="secondary"
                icon={EnvelopeSimpleIcon}
                external
              >
                Email this sponsor
              </LinkButton>
            )}
          </>
        }
      />

      <div className="grid gap-4 lg:grid-cols-3">
        <div className="flex flex-col gap-4 lg:col-span-2">
          <div className="grid gap-4 md:grid-cols-2">
            <div className="flex flex-col gap-4">
              <BasicInformation
                sponsorship={sponsorship}
                downloadHref={`${sponsorshipBase}/download_asset`}
              />
              <Card title="Organization">
                {sponsorship.organization === undefined ? (
                  <Text variant="secondary">Unknown</Text>
                ) : (
                  <Link
                    href={generatePath(paths.organization, {
                      domain: sponsorship.organization.domain,
                    })}
                  >
                    {sponsorship.organization.name}
                  </Link>
                )}
              </Card>
            </div>
            <div className="flex flex-col gap-4">
              <Invitations sponsorship={sponsorship} />
              <Requests sponsorship={sponsorship} />
              {sponsorship.boothAssigned && (
                <Card title="Booth details">
                  {sponsorship.exhibitionDescription === undefined ? (
                    <Badge variant="warning">Not submitted</Badge>
                  ) : (
                    <Text>
                      <span className="whitespace-pre-wrap">
                        {sponsorship.exhibitionDescription}
                      </span>
                    </Text>
                  )}
                </Card>
              )}
              {sponsorship.sponsorEvents.length > 0 && (
                <Card title="Events">
                  <ul className="flex flex-col gap-1">
                    {sponsorship.sponsorEvents.map((event) => {
                      const status = labelOf(EVENT_STATUS_LABELS, event.status);
                      return (
                        <li key={event.id.toString()} className="flex justify-between gap-2">
                          <Link href={`${base}/events/${event.id}`}>{event.title}</Link>
                          <Badge variant={status.tone}>{status.text}</Badge>
                        </li>
                      );
                    })}
                  </ul>
                </Card>
              )}
              {sponsorship.customizationName !== undefined && (
                <ExpenseReport
                  sponsorship={sponsorship}
                  href={`${sponsorshipBase}/expense_report`}
                />
              )}
            </div>
          </div>

          <Card title="Introduction">
            <Text bold>{sponsorship.name}</Text>
            <Text>
              <span className="whitespace-pre-wrap">{sponsorship.profile}</span>
            </Text>
            <div className="flex flex-wrap justify-between gap-2">
              {isWebUrl(sponsorship.url) ? (
                <Link href={sponsorship.url} target="_blank" rel="noreferrer" className="break-all">
                  {sponsorship.url}
                </Link>
              ) : (
                <Text variant="mono">{sponsorship.url}</Text>
              )}
              <Text variant={isOverWordLimit(sponsorship) ? "error" : "secondary"} size="sm">
                {wordCountText(sponsorship)}
              </Text>
            </div>
          </Card>
        </div>

        <LayerCard>
          <LayerCard.Secondary className="flex items-center justify-between gap-2">
            <span>Notes</span>
            <Link href={generatePath(paths.sponsorshipStaffNotes, pathParams)}>Show all</Link>
          </LayerCard.Secondary>
          <LayerCard.Primary>
            <StaffNotes
              target={target}
              notes={[...data.pinnedStaffNotes, ...data.recentStaffNotes]}
            />
          </LayerCard.Primary>
        </LayerCard>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <Card title="Contact">
          {sponsorship.contact !== undefined && <ContactDetails contact={sponsorship.contact} />}
        </Card>
        <Card
          title="Billing"
          badge={
            sponsorship.alternateBillingContact !== undefined && (
              <Badge variant="error">Alternate billing contact specified</Badge>
            )
          }
        >
          {billingContact !== undefined && <ContactDetails contact={billingContact} />}
        </Card>
      </div>

      <DangerZone
        sponsorship={sponsorship}
        target={target}
        impersonationEnabled={data.impersonationEnabled}
      />
    </div>
  );
}

function Card({
  title,
  badge,
  children,
}: {
  title: string;
  badge?: ReactNode;
  children: ReactNode;
}) {
  return (
    <LayerCard>
      <LayerCard.Secondary className="flex flex-wrap items-center gap-2">
        {title}
        {badge}
      </LayerCard.Secondary>
      <LayerCard.Primary className="flex flex-col gap-2">{children}</LayerCard.Primary>
    </LayerCard>
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

function BasicInformation({
  sponsorship,
  downloadHref,
}: {
  sponsorship: AdminSponsorship;
  downloadHref: string;
}) {
  const booth = boothStatus(sponsorship);
  const customization = customizationStatus(sponsorship);

  return (
    <Card title="Basic information">
      <div className="flex flex-wrap gap-1">
        {sponsorship.suspended && <Badge variant="warning">Presence suspended</Badge>}
        {sponsorship.state === SponsorshipState.WITHDRAWN && (
          <Badge variant="error">Withdrawn</Badge>
        )}
        {sponsorship.acceptedAt === undefined ? (
          <Badge variant="outline">Not accepted</Badge>
        ) : (
          <Badge variant="info">Accepted</Badge>
        )}
      </div>
      <dl className="grid grid-cols-[max-content_1fr] gap-x-3 gap-y-1">
        <Term label="Locale">{sponsorship.locale}</Term>
        <Term label="Assets">
          {sponsorship.assetFileUploaded ? (
            <Link href={downloadHref}>Download</Link>
          ) : (
            <Text variant="secondary">Not uploaded</Text>
          )}
        </Term>
        <Term label="Booth">
          <Badge variant={booth.tone}>{booth.text}</Badge>
        </Term>
        <Term label="Plan">
          {sponsorship.plan === undefined ? (
            <Badge variant="error">Undetermined</Badge>
          ) : (
            sponsorship.plan.name
          )}
        </Term>
        {sponsorship.fallbackOption !== "" && (
          <Term label="Fallback">
            <Text variant="mono">{sponsorship.fallbackOption}</Text>
          </Term>
        )}
        {customization !== undefined && (
          <Term label="Shown as">
            {customization.name}{" "}
            {!customization.confirmed && <Badge variant="warning">Custom plan: tentative</Badge>}
          </Term>
        )}
      </dl>
    </Card>
  );
}

function Invitations({ sponsorship }: { sponsorship: AdminSponsorship }) {
  return (
    <Card title="Invitations">
      <dl className="grid grid-cols-[max-content_1fr] gap-x-3 gap-y-1">
        <Term label="Included">{sponsorship.includedAttendees}</Term>
        <Term label="Additional">{sponsorship.numberOfAdditionalAttendees ?? 0}</Term>
        <Term label="Total">{sponsorship.totalAttendees}</Term>
      </dl>
      {sponsorship.titoDiscountCodes.length > 0 && (
        <dl className="grid grid-cols-[max-content_1fr] gap-x-3 gap-y-1">
          <Term label="Registration">
            <LinkList
              links={sponsorship.titoDiscountCodes.map((code) => ({
                label: titoKindLabel(code.kind),
                href: code.registrationUrl,
              }))}
            />
          </Term>
          <Term label="Orders">
            <LinkList
              links={sponsorship.titoDiscountCodes.map((code) => ({
                label: titoKindLabel(code.kind),
                href: code.dashboardUrl,
              }))}
            />
          </Term>
        </dl>
      )}
    </Card>
  );
}

function LinkList({ links }: { links: Array<{ label: string; href: string }> }) {
  return (
    <span className="flex flex-wrap gap-x-3">
      {links.map(({ label, href }) => (
        <Link key={href} href={href} target="_blank" rel="noreferrer">
          {label}
        </Link>
      ))}
    </span>
  );
}

function Requests({ sponsorship }: { sponsorship: AdminSponsorship }) {
  const requests = [
    { title: "Customization", body: sponsorship.customizationRequest },
    { title: "Billing", body: sponsorship.billingRequest },
    { title: "Others", body: sponsorship.note },
  ].filter(({ body }) => body !== "");

  return (
    <Card title="Requests">
      {requests.length === 0 && <Text variant="secondary">None</Text>}
      {requests.map(({ title, body }) => (
        <section key={title} className="flex flex-col gap-1">
          <Text bold>{title}</Text>
          <Text>
            <span className="whitespace-pre-wrap">{body}</span>
          </Text>
        </section>
      ))}
    </Card>
  );
}

function ExpenseReport({ sponsorship, href }: { sponsorship: AdminSponsorship; href: string }) {
  const report = sponsorship.expenseReport;
  if (report === undefined) {
    return (
      <Card title="Expense report">
        <Text variant="secondary">No report created</Text>
      </Card>
    );
  }
  const status = labelOf(EXPENSE_REPORT_STATUS_LABELS, report.status);
  return (
    <Card title="Expense report">
      <Text>
        <Badge variant={status.tone}>{status.text}</Badge> {formatAmount(report.totalAmount)} (+{" "}
        {formatAmount(report.totalTaxAmount)} tax)
      </Text>
      <div>
        <LinkButton href={href} variant="secondary" size="sm">
          View report
        </LinkButton>
      </div>
    </Card>
  );
}

function ContactDetails({ contact }: { contact: AdminSponsorship_Contact }) {
  return (
    <div className="flex flex-col gap-2">
      <Text>
        {contact.name}{" "}
        <Link href={contact.composeEmailUrl} target="_blank" rel="noreferrer" className="break-all">
          {contact.email}
        </Link>
      </Text>
      {contact.emailCc !== undefined && (
        <Text variant="secondary" size="sm">
          <span className="break-all">CC: {contact.emailCc}</span>
        </Text>
      )}
      <Text>
        {contact.unit !== undefined && (
          <>
            {contact.unit}
            <br />
          </>
        )}
        {contact.organization}
      </Text>
      <Text>{contact.address}</Text>
    </div>
  );
}

function DangerZone({
  sponsorship,
  target,
  impersonationEnabled,
}: {
  sponsorship: AdminSponsorship;
  target: { conferenceSlug: string; sponsorshipId: bigint };
  impersonationEnabled: boolean;
}) {
  const { mutate } = useSWRConfig();
  const withdraw = useRpcMutation(AdminService.method.withdrawSponsorship);
  const impersonate = useRpcMutation(AdminService.method.impersonateSponsorship);
  const withdrawn = sponsorship.state === SponsorshipState.WITHDRAWN;

  async function handleImpersonate() {
    let claimPath: string;
    try {
      claimPath = (await impersonate.trigger(target)).claimPath;
    } catch (error) {
      notifyError(error);
      return;
    }
    // The claim path is a Rails page, which signs this browser in as the sponsor.
    window.location.assign(claimPath);
  }

  if (withdrawn && !impersonationEnabled) return null;

  return (
    <LayerCard className="ring-kumo-danger">
      <LayerCard.Secondary className="text-kumo-danger">Danger zone</LayerCard.Secondary>
      <LayerCard.Primary className="flex flex-row flex-wrap gap-2">
        {!withdrawn && (
          <ConfirmButton
            label="Withdraw"
            icon={SignOutIcon}
            title={`Withdraw ${sponsorship.name}?`}
            description="The sponsorship loses its plan and booth, and the sponsor list, chat and ticketing service are updated. Withdrawal cannot be undone."
            confirmLabel="Withdraw"
            onConfirm={async () => {
              await withdraw.trigger(target);
              toastManager.add({ variant: "success", title: `Withdrew ${sponsorship.name}` });
              await mutate(
                (key) =>
                  isRpcKeyOf(key, AdminService.method.getSponsorship) ||
                  isRpcKeyOf(key, AdminService.method.getConference) ||
                  isRpcKeyOf(key, AdminService.method.listSponsorshipEditingHistory),
              );
            }}
          />
        )}
        {impersonationEnabled && (
          <Button
            variant="secondary"
            icon={MaskHappyIcon}
            loading={impersonate.isMutating}
            onClick={() => void handleImpersonate()}
          >
            Impersonate
          </Button>
        )}
      </LayerCard.Primary>
    </LayerCard>
  );
}
