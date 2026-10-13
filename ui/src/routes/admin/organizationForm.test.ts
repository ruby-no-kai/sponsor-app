import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toJson } from "@bufbuild/protobuf";
import {
  AdminOrganizationSchema,
  OrganizationInputSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_organizations_pb.ts";
import { organizationInputFrom, organizationValuesFrom } from "./organizationForm.ts";

describe("organizationValuesFrom and organizationInputFrom", () => {
  it("give back the input an organization was saved from", () => {
    const organization = create(AdminOrganizationSchema, {
      domain: "contoso.example.co.invalid",
      name: "Example KK",
      autoAcceptanceDisabled: true,
      affiliationCode: "code",
      sponsorshipCount: 3,
    });

    const input = create(
      OrganizationInputSchema,
      organizationInputFrom(organizationValuesFrom(organization)),
    );

    assert.deepEqual(toJson(OrganizationInputSchema, input), {
      name: "Example KK",
      domain: "contoso.example.co.invalid",
      autoAcceptanceDisabled: true,
    });
  });

  it("start a new organization with the defaults of the organizations table", () => {
    assert.deepEqual(organizationValuesFrom(undefined), {
      name: "",
      domain: "",
      autoAcceptanceDisabled: false,
    });
  });

  it("leave the domain as typed for the server to judge", () => {
    const values = { name: "Example", domain: "Example.INVALID ", autoAcceptanceDisabled: false };

    assert.equal(organizationInputFrom(values).domain, "Example.INVALID ");
  });
});
