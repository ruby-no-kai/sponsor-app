import type { MessageInitShape } from "@bufbuild/protobuf";
import type {
  AdminOrganization,
  OrganizationInputSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_organizations_pb.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";

// Named after OrganizationInput's JSON fields, so a google.rpc.BadRequest field path below
// "input." is the name of the form field it concerns.
export type OrganizationValues = {
  name: string;
  domain: string;
  autoAcceptanceDisabled: boolean;
};

// What the editor labels each field, in the order it lays them out.
export const FIELD_LABELS: Readonly<Record<keyof OrganizationValues, string>> = {
  name: "Name",
  domain: "Domain",
  autoAcceptanceDisabled: "Never accept applications automatically",
};

export const ORGANIZATION_LAYOUT: FieldLayout = { labels: FIELD_LABELS };

// A new organization starts with the defaults of the organizations table.
export function organizationValuesFrom(
  organization: AdminOrganization | undefined,
): OrganizationValues {
  return {
    name: organization?.name ?? "",
    domain: organization?.domain ?? "",
    autoAcceptanceDisabled: organization?.autoAcceptanceDisabled ?? false,
  };
}

// The server judges every value, the domain's case included.
export function organizationInputFrom(
  values: OrganizationValues,
): MessageInitShape<typeof OrganizationInputSchema> {
  return {
    name: values.name,
    domain: values.domain,
    autoAcceptanceDisabled: values.autoAcceptanceDisabled,
  };
}
