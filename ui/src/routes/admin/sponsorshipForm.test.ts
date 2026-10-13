import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toJson } from "@bufbuild/protobuf";
import type { MessageInitShape } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";
import { Code, ConnectError } from "@connectrpc/connect";
import { BadRequestSchema } from "../../gen/google/rpc/error_details_pb.ts";
import {
  AdminSponsorshipSchema,
  AdminSponsorship_PlanSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_sponsorship_pb.ts";
import { AdminSponsorshipInputSchema } from "../../gen/rubykaigi/sponsor_app/admin_sponsorships_pb.ts";
import { FallbackOptionSchema } from "../../gen/rubykaigi/sponsor_app/form_description_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import {
  fallbackOptionItems,
  formValuesFrom,
  inputFrom,
  planTerms,
  wordCount,
} from "./sponsorshipForm.ts";

const contact = {
  email: "contact@example.invalid",
  emailCc: "cc@example.invalid",
  address: "Tokyo",
  organization: "Contoso",
  name: "Contact",
  composeEmailUrl: "https://app.frontapp.com/compose?mailto=x",
};

const init: MessageInitShape<typeof AdminSponsorshipSchema> = {
  id: 42n,
  name: "Contoso",
  url: "https://contoso.example.invalid",
  profile: "We make tools",
  plan: { id: 7n, name: "Gold" },
  boothRequested: true,
  fallbackOption: "withdraw",
  customization: true,
  customizationName: "Ruby Lounge",
  acceptedAt: timestampFromDate(new Date("2026-04-01T00:00:00Z")),
  numberOfAdditionalAttendees: 2,
  contact,
  billingRequest: "Invoice to HQ",
};
const sponsorship = create(AdminSponsorshipSchema, init);

describe("formValuesFrom and inputFrom", () => {
  it("give back the input the sponsorship was saved from", () => {
    const values = formValuesFrom(sponsorship);

    assert.equal(values.planId, "7");
    assert.equal(values.accepted, true);
    assert.equal(values.numberOfAdditionalAttendees, "2");
    assert.equal(values.contact.unit, "");
    assert.equal(values.specifiesBillingContact, false);
    assert.deepEqual(
      toJson(AdminSponsorshipInputSchema, create(AdminSponsorshipInputSchema, inputFrom(values))),
      {
        planId: "7",
        name: "Contoso",
        url: "https://contoso.example.invalid",
        profile: "We make tools",
        boothRequested: true,
        fallbackOption: "withdraw",
        customization: true,
        customizationName: "Ruby Lounge",
        accepted: true,
        numberOfAdditionalAttendees: 2,
        contact: {
          email: "contact@example.invalid",
          emailCc: "cc@example.invalid",
          address: "Tokyo",
          organization: "Contoso",
          name: "Contact",
        },
        billingRequest: "Invoice to HQ",
      },
    );
  });

  it("leave out an undetermined plan, unset tickets and an unspecified billing contact", () => {
    const values = {
      ...formValuesFrom(sponsorship),
      planId: "",
      numberOfAdditionalAttendees: "",
      alternateBillingContact: {
        email: "billing@example.invalid",
        address: "Osaka",
        organization: "Contoso",
        unit: "",
        name: "Billing",
      },
    };
    const input = create(AdminSponsorshipInputSchema, inputFrom(values));

    assert.equal(input.planId, undefined);
    assert.equal(input.numberOfAdditionalAttendees, undefined);
    assert.equal(input.alternateBillingContact, undefined);

    const specified = create(
      AdminSponsorshipInputSchema,
      inputFrom({ ...values, specifiesBillingContact: true }),
    );
    assert.equal(specified.alternateBillingContact?.email, "billing@example.invalid");
  });

  it("start a billing contact from the stored one", () => {
    const values = formValuesFrom(
      create(AdminSponsorshipSchema, {
        ...init,
        alternateBillingContact: {
          ...contact,
          email: "billing@example.invalid",
          unit: "Accounting",
        },
      }),
    );

    assert.equal(values.specifiesBillingContact, true);
    assert.deepEqual(values.alternateBillingContact, {
      email: "billing@example.invalid",
      address: "Tokyo",
      organization: "Contoso",
      unit: "Accounting",
      name: "Contact",
    });
  });

  it("leave empty optional strings unset, so the nulls they stand for stay null", () => {
    const values = formValuesFrom(
      create(AdminSponsorshipSchema, {
        ...init,
        customizationName: undefined,
        contact: { ...contact, emailCc: undefined, unit: undefined },
      }),
    );
    const input = create(
      AdminSponsorshipInputSchema,
      inputFrom({ ...values, specifiesBillingContact: true }),
    );

    assert.equal(input.customizationName, undefined);
    assert.equal(input.contact?.emailCc, undefined);
    assert.equal(input.contact?.unit, undefined);
    assert.equal(input.alternateBillingContact?.unit, undefined);
  });

  it("refuses tickets that are no whole number", () => {
    assert.throws(
      () => inputFrom({ ...formValuesFrom(sponsorship), numberOfAdditionalAttendees: "1.5" }),
      RangeError,
    );
  });
});

describe("fieldViolations", () => {
  it("names the nested form fields the values are named after", () => {
    const error = new ConnectError("invalid", Code.InvalidArgument, undefined, [
      {
        desc: BadRequestSchema,
        value: {
          fieldViolations: [
            { field: "input.contact.emailCc", description: "is invalid" },
            {
              field: "input.alternateBillingContact.email",
              description: "value must be a valid email address",
            },
          ],
        },
      },
    ]);

    assert.deepEqual(fieldViolations(error, { prefix: "input." }).fields, {
      "contact.emailCc": "is invalid",
      "alternateBillingContact.email": "must be a valid email address",
    });
  });
});

describe("planTerms", () => {
  it("lists price, guests, booth and talk as the plan offers them", () => {
    const plan = create(AdminSponsorship_PlanSchema, {
      name: "Ruby",
      priceText: "JPY 3,000,000",
      numberOfGuests: 5,
      boothSize: 2,
      talkable: true,
    });

    assert.equal(planTerms(plan), "JPY 3,000,000, 5 guests, booth size 2, Talk");
    assert.equal(
      planTerms({ ...plan, priceText: "", numberOfGuests: 1, boothSize: 0, talkable: false }),
      "1 guest",
    );
  });
});

describe("fallbackOptionItems", () => {
  const choices = [
    create(FallbackOptionSchema, { value: "gold", name: "Change to Gold" }),
    create(FallbackOptionSchema, { value: "gold", name: "Change to Gold with booth" }),
    create(FallbackOptionSchema, { value: "withdraw", name: "Withdraw" }),
  ];

  it("offers none and each value once", () => {
    assert.deepEqual(fallbackOptionItems(choices, "gold"), [
      { label: "(none)", value: "" },
      { label: "Change to Gold", value: "gold" },
      { label: "Withdraw", value: "withdraw" },
    ]);
  });

  it("keeps a value the form no longer offers", () => {
    assert.deepEqual(fallbackOptionItems([], "silver").at(-1), {
      label: "silver (not offered by the form)",
      value: "silver",
    });
  });
});

describe("wordCount", () => {
  it("counts words as the server does, apostrophes and hyphens inside", () => {
    assert.equal(wordCount("We're a Ruby-first company’s team."), 5);
    assert.equal(wordCount("  "), 0);
  });
});
