import { Badge, Empty, LayerCard, Link, LinkButton, Loader, Table, Text } from "@cloudflare/kumo";
import { CoinsIcon, PencilSimpleIcon, PlusIcon } from "@phosphor-icons/react";
import { generatePath, useParams } from "react-router";
import type { AdminPlan } from "../../gen/rubykaigi/sponsor_app/admin_plans_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { formatTimestamp } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { StackedRow, TableOrStack } from "../../lib/StackedRows.tsx";
import { paths } from "../paths.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";

export default function PlanList() {
  const { slug = "" } = useParams();
  const { data, error } = useRpc(AdminService.method.listPlans, { conferenceSlug: slug });
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, "Plans");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;

  const newPlan = generatePath(paths.planNew, { slug });

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[{ label: conferenceName, href: generatePath(paths.conference, { slug }) }]}
        title="Plans"
        actions={
          <LinkButton href={newPlan} variant="primary" icon={PlusIcon}>
            New plan
          </LinkButton>
        }
      />

      {data.plans.length === 0 ? (
        <Empty
          icon={<CoinsIcon size={32} />}
          title="No plans"
          description="This conference offers no sponsorship plan yet."
          contents={
            <LinkButton href={newPlan} variant="secondary" icon={PlusIcon}>
              Create the first plan
            </LinkButton>
          }
        />
      ) : (
        <LayerCard className="p-0">
          <TableOrStack
            stack={data.plans.map((plan) => (
              <PlanStackedRow key={plan.id.toString()} slug={slug} plan={plan} />
            ))}
            table={
              <div className="overflow-x-auto">
                <Table>
                  <Table.Header>
                    <Table.Row>
                      <Table.Head>Rank</Table.Head>
                      <Table.Head>Name</Table.Head>
                      <Table.Head>Summary</Table.Head>
                      <Table.Head>Price</Table.Head>
                      <Table.Head>Active sponsorships</Table.Head>
                      <Table.Head>Guests</Table.Head>
                      <Table.Head>Booth size</Table.Head>
                      <Table.Head>Words limit</Table.Head>
                      <Table.Head>Closes at</Table.Head>
                      <Table.Head>Auto accept</Table.Head>
                      <Table.Head>Sponsor session</Table.Head>
                      <Table.Head />
                    </Table.Row>
                  </Table.Header>
                  <Table.Body>
                    {data.plans.map((plan) => (
                      <PlanRow key={plan.id.toString()} slug={slug} plan={plan} />
                    ))}
                  </Table.Body>
                </Table>
              </div>
            }
          />
        </LayerCard>
      )}
    </div>
  );
}

function PlanStackedRow({ slug, plan }: { slug: string; plan: AdminPlan }) {
  const edit = generatePath(paths.planEdit, { slug, id: plan.id.toString() });
  return (
    <StackedRow>
      <span className="inline-flex flex-wrap items-center gap-1">
        <Link href={edit}>{plan.name}</Link>
        {plan.soldOut && <Badge variant="error">Sold out</Badge>}
        {plan.closed && <Badge variant="warning">Closed</Badge>}
      </span>
      <Text variant="secondary" size="sm">
        {[
          plan.priceText,
          `${plan.activeSponsorshipCount}/${plan.capacity} sponsors`,
          plan.closesAt === undefined ? undefined : `closes ${formatTimestamp(plan.closesAt)}`,
        ]
          .filter((part) => part !== undefined && part !== "")
          .join(" · ")}
      </Text>
      <Text variant="secondary" size="sm">
        {[
          `${plan.numberOfGuests} guests`,
          `${plan.wordsLimit} words`,
          (plan.boothSize ?? 0) > 0 ? `booth ${plan.boothSize}` : undefined,
          plan.autoAcceptance ? "auto accept" : undefined,
        ]
          .filter((part) => part !== undefined)
          .join(" · ")}
      </Text>
    </StackedRow>
  );
}

function PlanRow({ slug, plan }: { slug: string; plan: AdminPlan }) {
  const edit = generatePath(paths.planEdit, { slug, id: plan.id.toString() });
  return (
    <Table.Row>
      <Table.Cell>{plan.rank}</Table.Cell>
      <Table.Cell>
        <span className="inline-flex flex-wrap items-center gap-1">
          <Link href={edit}>{plan.name}</Link>
          {plan.soldOut && <Badge variant="error">Sold out</Badge>}
          {plan.closed && <Badge variant="warning">Closed</Badge>}
        </span>
      </Table.Cell>
      <Table.Cell>{plan.summary}</Table.Cell>
      <Table.Cell>{plan.priceText}</Table.Cell>
      <Table.Cell>
        {plan.activeSponsorshipCount}/{plan.capacity}
      </Table.Cell>
      <Table.Cell>{plan.numberOfGuests}</Table.Cell>
      <Table.Cell>{plan.boothSize}</Table.Cell>
      <Table.Cell>{plan.wordsLimit}</Table.Cell>
      <Table.Cell>{formatTimestamp(plan.closesAt, "")}</Table.Cell>
      <Table.Cell>
        {plan.autoAcceptance ? (
          <Badge variant="success">Yes</Badge>
        ) : (
          <Badge variant="outline">No</Badge>
        )}
      </Table.Cell>
      <Table.Cell>{plan.talkable && <Badge variant="info">Included</Badge>}</Table.Cell>
      <Table.Cell>
        <LinkButton href={edit} variant="secondary" size="sm" icon={PencilSimpleIcon}>
          Edit
        </LinkButton>
      </Table.Cell>
    </Table.Row>
  );
}
