import { Badge, Empty, LayerCard, Link, LinkButton, Loader, Table, Text } from "@cloudflare/kumo";
import { BuildingsIcon, PencilSimpleIcon, PlusIcon } from "@phosphor-icons/react";
import { generatePath } from "react-router";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { useRpc } from "../../lib/rpc.ts";
import { StackedRow, TableOrStack } from "../../lib/StackedRows.tsx";
import { useDocumentTitle } from "../../lib/title.ts";
import { paths } from "../paths.ts";

export default function OrganizationList() {
  const { data, error } = useRpc(AdminService.method.listOrganizations, {});
  useDocumentTitle("Organizations");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;

  const anyAutoAcceptanceOff = data.organizations.some(
    (organization) => organization.autoAcceptanceDisabled,
  );

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <Text variant="heading" size="lg" as="h2">
          Organizations
        </Text>
        <LinkButton href={paths.organizationNew} variant="primary" icon={PlusIcon}>
          New organization
        </LinkButton>
      </div>

      {data.organizations.length === 0 ? (
        <Empty
          icon={<BuildingsIcon size={32} />}
          title="No organizations"
          description="An organization is added when its first application arrives."
        />
      ) : (
        <LayerCard className="p-0">
          <TableOrStack
            stack={data.organizations.map((organization) => (
              <StackedRow key={organization.domain}>
                <Link href={generatePath(paths.organization, { domain: organization.domain })}>
                  {organization.name}
                </Link>
                <Text variant="mono">{organization.domain}</Text>
                <div className="flex flex-wrap items-center gap-2">
                  <Text variant="secondary" size="sm">
                    {organization.sponsorshipCount === 1
                      ? "1 sponsorship"
                      : `${organization.sponsorshipCount} sponsorships`}
                  </Text>
                  {organization.autoAcceptanceDisabled && (
                    <Badge variant="warning">Auto-acceptance off</Badge>
                  )}
                </div>
              </StackedRow>
            ))}
            table={
              <Table>
                <Table.Header>
                  <Table.Row>
                    <Table.Head>Name</Table.Head>
                    <Table.Head>Domain</Table.Head>
                    <Table.Head>Sponsorships</Table.Head>
                    {anyAutoAcceptanceOff && <Table.Head>Auto-acceptance</Table.Head>}
                    <Table.Head />
                  </Table.Row>
                </Table.Header>
                <Table.Body>
                  {data.organizations.map((organization) => {
                    const params = { domain: organization.domain };
                    return (
                      <Table.Row key={organization.domain}>
                        <Table.Cell>
                          <Link href={generatePath(paths.organization, params)}>
                            {organization.name}
                          </Link>
                        </Table.Cell>
                        <Table.Cell>
                          <Text variant="mono">{organization.domain}</Text>
                        </Table.Cell>
                        <Table.Cell>{organization.sponsorshipCount}</Table.Cell>
                        {anyAutoAcceptanceOff && (
                          <Table.Cell>
                            {organization.autoAcceptanceDisabled && (
                              <Badge variant="warning">Off</Badge>
                            )}
                          </Table.Cell>
                        )}
                        <Table.Cell>
                          <LinkButton
                            href={generatePath(paths.organizationEdit, params)}
                            variant="secondary"
                            size="sm"
                            icon={PencilSimpleIcon}
                          >
                            Edit
                          </LinkButton>
                        </Table.Cell>
                      </Table.Row>
                    );
                  })}
                </Table.Body>
              </Table>
            }
          />
        </LayerCard>
      )}
    </div>
  );
}
