import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toJson } from "@bufbuild/protobuf";
import type { MessageInitShape } from "@bufbuild/protobuf";
import { Code, ConnectError } from "@connectrpc/connect";
import { BadRequestSchema } from "../../gen/google/rpc/error_details_pb.ts";
import { FallbackOptionSchema } from "../../gen/rubykaigi/sponsor_app/form_description_pb.ts";
import type { FallbackOption } from "../../gen/rubykaigi/sponsor_app/form_description_pb.ts";
import {
  ApplicationPlanSchema,
  SponsorshipApplicationSchema,
  SponsorshipInputSchema,
} from "../../gen/rubykaigi/sponsor_app/sponsor_applications_pb.ts";
import { FileTooLargeError, StorageError } from "../../lib/upload.ts";
import {
  OTHER_PLAN,
  assetFileHref,
  boothApplies,
  fieldLabelKeys,
  formValuesFrom,
  initialValues,
  inputFrom,
  isFallbackOptionOffered,
  isPlanSelectable,
  isZipFile,
  looksNonEnglish,
  offeredFallbackOptions,
  offersOtherPlan,
  priorityItems,
  saveErrors,
  ticketCounts,
  uploadFailure,
  validateApplication,
} from "./applicationForm.ts";
import type { ApplicationValues, ValidationMessages } from "./applicationForm.ts";

const application = create(SponsorshipApplicationSchema, {
  planId: 7n,
  name: "Contoso",
  url: "https://contoso.example.invalid",
  profile: "We make tools",
  boothRequested: true,
  fallbackOption: "gold",
  numberOfAdditionalAttendees: 2,
  contact: {
    email: "contact@contoso.example.invalid",
    emailCc: "cc@contoso.example.invalid",
    address: "Tokyo",
    organization: "Contoso",
    name: "Contact",
  },
  billingRequest: "Invoice in PDF",
  assetFile: { id: 11n, extension: "svg" },
});

const plan = (fields: MessageInitShape<typeof ApplicationPlanSchema> = {}) =>
  create(ApplicationPlanSchema, {
    id: 7n,
    name: "Ruby",
    numberOfGuests: 3,
    boothEligible: true,
    available: true,
    ...fields,
  });

const messages: ValidationMessages = {
  required: "required",
  choosePlan: "choose a plan",
  email: "not an email",
  url: "not a URL",
  wholeNumber: "not a whole number",
  chooseFile: "choose a file",
  acknowledge: "acknowledge",
  agree: "agree",
};

const svg = new File(["<svg/>"], "logo.svg", { type: "image/svg+xml" });

function completeValues(fields: Partial<ApplicationValues> = {}): ApplicationValues {
  return {
    ...formValuesFrom(application, { saved: true }),
    policyAgreement: true,
    ...fields,
  };
}

describe("formValuesFrom and inputFrom", () => {
  it("give back the input the application was saved from", () => {
    const values = formValuesFrom(application, { saved: true });

    assert.equal(values.planId, "7");
    assert.equal(values.contact.unit, "");
    assert.equal(values.specifiesBillingContact, false);
    assert.deepEqual(values.assetFileId, { kind: "existing", id: "11" });
    assert.deepEqual(
      toJson(SponsorshipInputSchema, create(SponsorshipInputSchema, inputFrom(values, 11n))),
      {
        planId: "7",
        name: "Contoso",
        url: "https://contoso.example.invalid",
        profile: "We make tools",
        boothRequested: true,
        fallbackOption: "gold",
        numberOfAdditionalAttendees: 2,
        contact: {
          email: "contact@contoso.example.invalid",
          emailCc: "cc@contoso.example.invalid",
          address: "Tokyo",
          organization: "Contoso",
          name: "Contact",
        },
        billingRequest: "Invoice in PDF",
        assetFileId: "11",
      },
    );
  });

  it("start a saved application without a plan at Other, and a new one at nothing", () => {
    const withoutPlan = create(SponsorshipApplicationSchema, { name: "Contoso" });

    assert.equal(formValuesFrom(withoutPlan, { saved: true }).planId, OTHER_PLAN);
    assert.equal(formValuesFrom(withoutPlan, { saved: false }).planId, "");
    assert.deepEqual(formValuesFrom(undefined, { saved: false }).assetFileId, { kind: "none" });
  });

  it("send no plan for Other, and the billing contact only when specified", () => {
    const values = completeValues({
      planId: OTHER_PLAN,
      specifiesBillingContact: true,
      alternateBillingContact: {
        email: "billing@contoso.example.invalid",
        address: "Osaka",
        organization: "Contoso",
        unit: "",
        name: "Billing",
      },
    });
    const input = inputFrom(values, 11n);

    assert.equal(input.planId, undefined);
    assert.deepEqual(input.alternateBillingContact, {
      email: "billing@contoso.example.invalid",
      address: "Osaka",
      organization: "Contoso",
      unit: undefined,
      name: "Billing",
    });
    assert.equal(
      inputFrom({ ...values, specifiesBillingContact: false }, 11n).alternateBillingContact,
      undefined,
    );
  });

  it("refuse an additional ticket count that is no whole number", () => {
    assert.throws(
      () => inputFrom(completeValues({ numberOfAdditionalAttendees: "two" }), 11n),
      RangeError,
    );
  });
});

describe("initialValues", () => {
  const withoutPlan = create(SponsorshipApplicationSchema, { boothRequested: true });
  const boothOnly = [
    create(FallbackOptionSchema, {
      value: "gold",
      name: "Gold",
      conditions: [{ boothRequest: true }],
    }),
  ];
  const silver = [create(FallbackOptionSchema, { value: "silver", name: "Silver" })];

  it("drop a saved booth request on a plan without a booth, or on Other", () => {
    const start = (saved: typeof application, plans: ReturnType<typeof plan>[]) =>
      initialValues(saved, { saved: true, plans, fallbackOptions: [] }).boothRequested;

    assert.equal(start(application, [plan()]), true);
    assert.equal(start(application, [plan({ boothEligible: false })]), false);
    assert.equal(start(withoutPlan, [plan()]), false);
  });

  it("drop a saved fallback option the form does not offer", () => {
    const start = (plans: ReturnType<typeof plan>[], fallbackOptions: FallbackOption[]) =>
      initialValues(application, { saved: true, plans, fallbackOptions }).fallbackOption;

    assert.equal(start([plan()], boothOnly), "gold");
    assert.equal(start([plan({ boothEligible: false })], boothOnly), "");
    assert.equal(start([plan()], silver), "");
  });

  it("keep a saved fallback option while the form lists none", () => {
    assert.equal(
      initialValues(application, { saved: true, plans: [plan()], fallbackOptions: [] })
        .fallbackOption,
      "gold",
    );
  });
});

describe("plans", () => {
  it("keep an unavailable plan selectable for the application that has it", () => {
    const soldOut = plan({ available: false, soldOut: true });

    assert.ok(!isPlanSelectable(soldOut, undefined));
    assert.ok(!isPlanSelectable(soldOut, 8n));
    assert.ok(isPlanSelectable(soldOut, 7n));
  });

  it("offer Other where no plan is allowed, or to an application saved without one", () => {
    const strict = { noPlanAllowed: false };

    assert.ok(offersOtherPlan({ noPlanAllowed: true }, { saved: false, savedPlanId: undefined }));
    assert.ok(!offersOtherPlan(strict, { saved: false, savedPlanId: undefined }));
    assert.ok(offersOtherPlan(strict, { saved: true, savedPlanId: undefined }));
    assert.ok(!offersOtherPlan(strict, { saved: true, savedPlanId: 7n }));
  });

  it("apply the booth request to a plan with a booth at a conference offering booths", () => {
    assert.ok(boothApplies({ boothsOffered: true }, plan()));
    assert.ok(!boothApplies({ boothsOffered: true }, plan({ boothEligible: false })));
    assert.ok(!boothApplies({ boothsOffered: true }, undefined));
    assert.ok(!boothApplies({ boothsOffered: false }, plan()));
  });
});

describe("fallback options", () => {
  const option = (value: string, conditions: { plans?: string[]; boothRequest?: boolean }[]) =>
    create(FallbackOptionSchema, { value, name: value, conditions });

  it("are offered when any condition matches every part it sets", () => {
    const platinumWithoutBooth = option("gold", [
      { plans: ["Platinum"], boothRequest: false },
      { boothRequest: true },
    ]);

    assert.ok(
      isFallbackOptionOffered(platinumWithoutBooth, {
        planName: "Platinum",
        boothRequested: false,
      }),
    );
    assert.ok(
      isFallbackOptionOffered(platinumWithoutBooth, { planName: "Ruby", boothRequested: true }),
    );
    assert.ok(
      !isFallbackOptionOffered(platinumWithoutBooth, { planName: "Ruby", boothRequested: false }),
    );
    assert.ok(
      !isFallbackOptionOffered(option("x", [{ plans: ["Ruby"] }]), {
        planName: undefined,
        boothRequested: false,
      }),
    );
  });

  it("are always offered without conditions, once per value", () => {
    const options: FallbackOption[] = [
      option("withdraw", []),
      option("gold", [{ plans: ["Platinum"] }]),
      option("gold", [{ boothRequest: true }]),
    ];

    assert.deepEqual(
      offeredFallbackOptions(options, { planName: "Platinum", boothRequested: true }).map(
        ({ value, conditions }) => [value, conditions.length],
      ),
      [
        ["withdraw", 0],
        ["gold", 1],
      ],
    );
    assert.deepEqual(
      offeredFallbackOptions(options, { planName: "Ruby", boothRequested: false }).map(
        ({ value }) => value,
      ),
      ["withdraw"],
    );
  });

  it("list the priorities after the plan applied for", () => {
    const labels = { withdraw: "Withdraw", booth: "with booth", noBooth: "without booth" };
    const priorityHuman = ["{plan}!no_booth", "Gold!booth", "!withdraw"];

    assert.deepEqual(
      priorityItems(
        { priorityHuman },
        { planName: "Platinum", boothApplies: true, boothRequested: true },
        labels,
      ),
      ["Platinum (with booth)", "Platinum (without booth)", "Gold (with booth)", "Withdraw"],
    );
    assert.deepEqual(
      priorityItems(
        { priorityHuman: ["!withdraw"] },
        { planName: "Ruby", boothApplies: false, boothRequested: false },
        labels,
      ),
      ["Ruby", "Withdraw"],
    );
  });
});

describe("looksNonEnglish", () => {
  it("passes Latin text with symbols and line breaks", () => {
    assert.ok(!looksNonEnglish("Contoso, Inc.", "We ♥ Ruby — 100% on Rails!\nSee café."));
  });

  it("catches other scripts in any of the texts", () => {
    assert.ok(looksNonEnglish("Contoso", "株式会社コントソ"));
    assert.ok(looksNonEnglish("コントソ", "We make tools"));
  });
});

describe("isZipFile", () => {
  it("tells a ZIP archive by its type or its name", () => {
    assert.ok(isZipFile({ name: "logos.bin", type: "application/zip" }));
    assert.ok(isZipFile({ name: "logos.bin", type: "application/x-zip-compressed" }));
    assert.ok(isZipFile({ name: "LOGOS.ZIP", type: "" }));
    assert.ok(!isZipFile(svg));
  });
});

describe("ticketCounts", () => {
  it("adds the additional tickets to the plan's", () => {
    assert.deepEqual(ticketCounts(plan(), "2"), { included: 3, total: 5 });
    assert.deepEqual(ticketCounts(plan(), ""), { included: 3, total: 3 });
    assert.deepEqual(ticketCounts(plan(), "-1"), { included: 3, total: 3 });
    assert.deepEqual(ticketCounts(plan(), "2147483648"), { included: 3, total: 3 });
    assert.deepEqual(ticketCounts(undefined, "2"), { included: 0, total: 2 });
  });
});

describe("validateApplication", () => {
  const creating = { creating: true, fallbackOffered: false };

  it("passes a complete application", () => {
    assert.equal(validateApplication(completeValues(), creating, messages), undefined);
  });

  it("requires what the HAML form requires", () => {
    const values = completeValues({
      planId: "",
      name: " ",
      url: "contoso.example.invalid",
      contact: { ...completeValues().contact, email: "contact", address: "" },
      assetFileId: { kind: "none" },
      policyAgreement: false,
    });

    assert.deepEqual(validateApplication(values, creating, messages), {
      fields: {
        "contact.email": "not an email",
        "contact.address": "required",
        planId: "choose a plan",
        name: "required",
        url: "not a URL",
        assetFileId: "choose a file",
        policyAgreement: "agree",
      },
    });
  });

  it("requires the billing contact only when specified", () => {
    const values = completeValues({ specifiesBillingContact: true });

    assert.deepEqual(Object.keys(validateApplication(values, creating, messages)?.fields ?? {}), [
      "alternateBillingContact.email",
      "alternateBillingContact.address",
      "alternateBillingContact.organization",
      "alternateBillingContact.name",
    ]);
  });

  it("requires a customization request for Other, and a fallback option while one is offered", () => {
    const values = completeValues({ planId: OTHER_PLAN, fallbackOption: "" });

    assert.deepEqual(
      validateApplication(values, { creating: true, fallbackOffered: true }, messages),
      { fields: { customizationRequest: "required", fallbackOption: "required" } },
    );
  });

  it("requires acknowledging non-English listing text and a ZIP archive", () => {
    const zip = new File(["PK"], "logos.zip", { type: "application/zip" });
    const values = completeValues({
      profile: "日本語の紹介文",
      assetFileId: { kind: "file", file: zip },
    });

    assert.deepEqual(validateApplication(values, creating, messages), {
      fields: { englishAcknowledged: "acknowledge", zipAcknowledged: "acknowledge" },
    });
    assert.equal(
      validateApplication(
        { ...values, englishAcknowledged: true, zipAcknowledged: true },
        creating,
        messages,
      ),
      undefined,
    );
  });

  it("refuses more additional tickets than an int32 holds", () => {
    const values = completeValues({ numberOfAdditionalAttendees: "2147483648" });

    assert.deepEqual(validateApplication(values, creating, messages), {
      fields: { numberOfAdditionalAttendees: "not a whole number" },
    });
  });

  it("leaves the policies to a new application", () => {
    const values = completeValues({ policyAgreement: false, numberOfAdditionalAttendees: "1.5" });

    assert.deepEqual(
      validateApplication(values, { creating: false, fallbackOffered: false }, messages),
      { fields: { numberOfAdditionalAttendees: "not a whole number" } },
    );
  });
});

describe("assetFileHref", () => {
  it("links the Rails download under the conference the logo belongs to", () => {
    assert.equal(
      assetFileHref("rubykaigi2048", 11n),
      "/conferences/rubykaigi2048/sponsorship_asset_files/11",
    );
  });
});

describe("fieldLabelKeys", () => {
  it("names a field by its own text, and a contact's by its section's too", () => {
    assert.deepEqual(fieldLabelKeys("planId"), ["sponsorships.form.plan"]);
    assert.deepEqual(fieldLabelKeys("alternateBillingContact.emailCc"), [
      "sponsor_ui.applications.billing_contact",
      "activerecord.attributes.contact.email_cc",
    ]);
    assert.deepEqual(fieldLabelKeys("input"), []);
  });
});

describe("saveErrors", () => {
  it("puts the Input's violations on the fields, and the rest on the form", () => {
    const badRequest = create(BadRequestSchema, {
      fieldViolations: [
        { field: "input.contact.email", description: "is invalid" },
        { field: "input.planId", description: "is sold out." },
        { field: "", description: "Organization has already been taken" },
      ],
    });
    const error = new ConnectError("invalid", Code.InvalidArgument, undefined, [
      { desc: BadRequestSchema, value: badRequest },
    ]);

    assert.deepEqual(saveErrors(error), {
      form: "Organization has already been taken",
      fields: { "contact.email": "is invalid", planId: "is sold out." },
    });
  });
});

describe("uploadFailure", () => {
  it("tells why a logo failed to upload", () => {
    const large = new File(["xx"], "large.svg");

    assert.deepEqual(uploadFailure(new FileTooLargeError(large, 1n)), {
      kind: "tooLarge",
      maxSize: 1n,
    });
    assert.deepEqual(uploadFailure(new StorageError(403)), { kind: "storage" });
    assert.deepEqual(uploadFailure(new ConnectError("bad type", Code.InvalidArgument)), {
      kind: "unsupportedType",
    });
    assert.equal(uploadFailure(new ConnectError("closed", Code.FailedPrecondition)).kind, "rpc");
  });
});
