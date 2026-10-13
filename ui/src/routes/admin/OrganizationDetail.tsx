import {
  Badge,
  ClipboardText,
  Empty,
  LayerCard,
  Link,
  LinkButton,
  Loader,
  Table,
  Text,
} from "@cloudflare/kumo";
import { HandshakeIcon, PencilSimpleIcon } from "@phosphor-icons/react";
import type { ReactNode } from "react";
import { generatePath, useParams } from "react-router";
import type { OrganizationSponsorship } from "../../gen/rubykaigi/sponsor_app/admin_organizations_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { SponsorshipState } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { StackedRow, TableOrStack } from "../../lib/StackedRows.tsx";
import { useDocumentTitle } from "../../lib/title.ts";
import { paths } from "../paths.ts";
import { labelOf } from "./sponsorshipView.ts";
import type { Label } from "./sponsorshipView.ts";

export default function OrganizationDetail() {
  const { domain = "" } = useParams();
  const { data, error } = useRpc(AdminService.method.getOrganization, { domain });
  useDocumentTitle(data?.organization?.name ?? domain, "Organizations");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const { organization } = data;
  if (organization === undefined) throw new Error("GetOrganization returned no organization");

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[{ label: "Organizations", href: paths.organizations }]}
        title={organization.name}
        actions={
          <LinkButton
            href={generatePath(paths.organizationEdit, { domain: organization.domain })}
            variant="primary"
            icon={PencilSimpleIcon}
          >
            Edit
          </LinkButton>
        }
      />

      <div className="grid gap-4 md:grid-cols-2">
        <Card title="Details">
          <dl className="grid grid-cols-[max-content_1fr] gap-x-3 gap-y-1">
            <Term label="Name">{organization.name}</Term>
            <Term label="Domain">
              <Text variant="mono">{organization.domain}</Text>
            </Term>
            <Term label="Auto-acceptance">
              {organization.autoAcceptanceDisabled ? (
                <Badge variant="warning">Disabled</Badge>
              ) : (
                <Badge variant="success">Enabled</Badge>
              )}
            </Term>
            <Term label="Affiliation code">
              <Text variant="mono">{organization.affiliationCode}</Text>
            </Term>
          </dl>
        </Card>

        <Card title="Affiliation URLs">
          <Text variant="secondary">
            An application sent from one of these is filed under this organization, whatever the
            applicant's email domain.
          </Text>
          {data.affiliationUrls.length === 0 ? (
            <Text variant="secondary">No conference is taking applications.</Text>
          ) : (
            <ul className="flex flex-col gap-2">
              {data.affiliationUrls.map(({ conference, url }) => (
                <li key={url} className="flex min-w-0 flex-col gap-1">
                  <Link href={url} target="_blank" rel="noopener">
                    {conference?.name ?? url}
                  </Link>
                  <ClipboardText text={url} size="sm" />
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <Card title="Sponsorships">
        {data.sponsorships.length === 0 ? (
          <Empty
            size="sm"
            icon={<HandshakeIcon size={32} />}
            title="No sponsorships"
            description="The organization has not applied to any conference."
          />
        ) : (
          <TableOrStack
            stack={data.sponsorships.map((entry) => (
              <SponsorshipStackedRow key={entry.sponsorship?.id.toString()} entry={entry} />
            ))}
            table={
              <Table>
                <Table.Header>
                  <Table.Row>
                    <Table.Head>Conference</Table.Head>
                    <Table.Head>Name</Table.Head>
                    <Table.Head>Plan</Table.Head>
                    <Table.Head>Custom</Table.Head>
                    <Table.Head>Booth</Table.Head>
                    <Table.Head>Status</Table.Head>
                  </Table.Row>
                </Table.Header>
                <Table.Body>
                  {data.sponsorships.map((entry) => (
                    <SponsorshipRow key={entry.sponsorship?.id.toString()} entry={entry} />
                  ))}
                </Table.Body>
              </Table>
            }
          />
        )}
      </Card>
    </div>
  );
}

function SponsorshipStackedRow({ entry }: { entry: OrganizationSponsorship }) {
  const { sponsorship, conference } = entry;
  if (sponsorship === undefined || conference === undefined)
    throw new Error("GetOrganization returned a sponsorship without its conference");
  const booth = boothLabel(entry);
  const status = labelOf(STATUS_LABELS, sponsorship.state);

  return (
    <StackedRow>
      <Link
        href={generatePath(paths.sponsorship, {
          slug: conference.slug,
          id: sponsorship.id.toString(),
        })}
      >
        {conference.name}
      </Link>
      <Text>{sponsorship.name}</Text>
      <Text variant="secondary" size="sm">
        {[entry.planName ?? "Other", sponsorship.customizationName]
          .filter((part) => part !== "")
          .join(" / ")}
      </Text>
      <div className="flex flex-wrap items-center gap-2">
        <Badge variant={status.tone}>{status.text}</Badge>
        {booth !== undefined && (
          <Badge variant={booth.tone}>Booth {booth.text.toLowerCase()}</Badge>
        )}
      </div>
    </StackedRow>
  );
}

function SponsorshipRow({ entry }: { entry: OrganizationSponsorship }) {
  const { sponsorship, conference } = entry;
  if (sponsorship === undefined || conference === undefined)
    throw new Error("GetOrganization returned a sponsorship without its conference");
  const booth = boothLabel(entry);
  const status = labelOf(STATUS_LABELS, sponsorship.state);

  return (
    <Table.Row>
      <Table.Cell>
        <Link
          href={generatePath(paths.sponsorship, {
            slug: conference.slug,
            id: sponsorship.id.toString(),
          })}
        >
          {conference.name}
        </Link>
      </Table.Cell>
      <Table.Cell>{sponsorship.name}</Table.Cell>
      <Table.Cell>
        {entry.planName ?? (
          <Text variant="secondary" as="span">
            <i>Other</i>
          </Text>
        )}
      </Table.Cell>
      <Table.Cell>{sponsorship.customizationName}</Table.Cell>
      <Table.Cell>
        {booth === undefined ? (
          <Text variant="secondary" as="span">
            —
          </Text>
        ) : (
          <Badge variant={booth.tone}>{booth.text}</Badge>
        )}
      </Table.Cell>
      <Table.Cell>
        <Badge variant={status.tone}>{status.text}</Badge>
      </Table.Cell>
    </Table.Row>
  );
}

const STATUS_LABELS: Readonly<Record<SponsorshipState, Label>> = {
  [SponsorshipState.UNSPECIFIED]: { text: "Unknown", tone: "outline" },
  [SponsorshipState.PENDING]: { text: "Pending", tone: "outline" },
  [SponsorshipState.ACTIVE]: { text: "Accepted", tone: "info" },
  [SponsorshipState.WITHDRAWN]: { text: "Withdrawn", tone: "error" },
};

function boothLabel(entry: OrganizationSponsorship): Label | undefined {
  if (entry.sponsorship?.boothAssigned) return { text: "Assigned", tone: "success" };
  if (entry.boothRequested) return { text: "Requested", tone: "info" };
  return undefined;
}

function Card({ title, children }: { title: string; children: ReactNode }) {
  return (
    <LayerCard>
      <LayerCard.Secondary>{title}</LayerCard.Secondary>
      <LayerCard.Primary className="flex flex-col gap-3">{children}</LayerCard.Primary>
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
