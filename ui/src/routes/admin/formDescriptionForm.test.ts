import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toBinary, toJson } from "@bufbuild/protobuf";
import { Code, ConnectError } from "@connectrpc/connect";
import { BadRequestSchema } from "../../gen/google/rpc/error_details_pb.ts";
import { FormDescriptionInputSchema } from "../../gen/rubykaigi/sponsor_app/admin_form_descriptions_pb.ts";
import { FormDescriptionSchema } from "../../gen/rubykaigi/sponsor_app/form_description_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import { errorAnchor, erroredFields, fieldLabel } from "../../lib/fieldErrors.ts";
import {
  FORM_DESCRIPTION_LAYOUT,
  FORM_LOCALES,
  boothRequestFromInput,
  boothRequestToInput,
  collidingOptions,
  defaultLocale,
  emptyFallbackOption,
  errorsAt,
  formValuesFrom,
  inputFrom,
  isBoothRequest,
  movedIndex,
  planChoices,
  withCollisions,
} from "./formDescriptionForm.ts";
import type { FallbackOptionValues } from "./formDescriptionForm.ts";

const formDescription = create(FormDescriptionSchema, {
  locale: "en",
  head: "# Welcome",
  headHtml: "<h1>Welcome</h1>",
  eventPolicy: "Be nice",
  fallbackOptions: [
    {
      value: "gold",
      name: "Change to Gold",
      conditions: [
        { plans: ["Platinum"], boothRequest: false },
        { plans: [], boothRequest: true },
        { plans: ["Ruby"] },
      ],
      priorityHuman: ["Gold", "!withdraw"],
    },
  ],
});

describe("formValuesFrom and inputFrom", () => {
  it("give back the input a form description was saved from", () => {
    const values = formValuesFrom(formDescription);
    const input = create(FormDescriptionInputSchema, inputFrom(values));

    assert.deepEqual(values.fallbackOptions[0]?.conditions, [
      { plans: ["Platinum"], boothRequest: "not_requested" },
      { plans: [], boothRequest: "requested" },
      { plans: ["Ruby"], boothRequest: "any" },
    ]);
    assert.deepEqual(toJson(FormDescriptionInputSchema, input), {
      locale: "en",
      head: "# Welcome",
      eventPolicy: "Be nice",
      fallbackOptions: [
        {
          value: "gold",
          name: "Change to Gold",
          conditions: [
            { plans: ["Platinum"], boothRequest: false },
            { boothRequest: true },
            { plans: ["Ruby"] },
          ],
          priorityHuman: ["Gold", "!withdraw"],
        },
      ],
    });
  });

  it("start a new form description empty, in the locale given", () => {
    assert.deepEqual(formValuesFrom(undefined, "ja"), {
      locale: "ja",
      head: "",
      planHelp: "",
      boothHelp: "",
      policyHelp: "",
      ticketHelp: "",
      sponsorEventHelp: "",
      eventPolicy: "",
      fallbackOptions: [],
    });
  });

  it("copy the lists, so editing the form leaves the message alone", () => {
    const values = formValuesFrom(formDescription);
    values.fallbackOptions[0]?.priorityHuman.push("Silver");

    assert.deepEqual(formDescription.fallbackOptions[0]?.priorityHuman, ["Gold", "!withdraw"]);
  });
});

describe("booth request", () => {
  it("keeps unset apart from false", () => {
    for (const boothRequest of [undefined, true, false]) {
      assert.equal(boothRequestFromInput(boothRequestToInput(boothRequest)), boothRequest);
    }
  });

  it("accepts only the select's own values", () => {
    for (const value of ["any", "requested", "not_requested"]) {
      assert.equal(isBoothRequest(value), true);
    }
    for (const value of [null, undefined, "", "toString", "true"]) {
      assert.equal(isBoothRequest(value), false);
    }
  });
});

describe("planChoices", () => {
  it("adds names the conference does not have after its plans", () => {
    assert.deepEqual(planChoices(["Ruby", "Platinum"], ["Platinum", "Diamond"]), [
      "Ruby",
      "Platinum",
      "Diamond",
    ]);
  });
});

describe("movedIndex", () => {
  it("stops at either end", () => {
    assert.equal(movedIndex(0, -1, 3), undefined);
    assert.equal(movedIndex(2, 1, 3), undefined);
    assert.equal(movedIndex(1, 1, 3), 2);
  });
});

describe("errorsAt", () => {
  // As TanStack Form holds the errors fieldViolations returned, under the field names.
  function metasFor(...violations: { field: string; description: string }[]) {
    const error = new ConnectError("invalid", Code.InvalidArgument);
    error.details.push({
      type: BadRequestSchema.typeName,
      value: toBinary(BadRequestSchema, create(BadRequestSchema, { fieldViolations: violations })),
    });
    const { fields } = fieldViolations(error, { prefix: "input." });
    return Object.fromEntries(
      Object.entries(fields).map(([name, message]) => [name, { errors: [message] }]),
    );
  }

  it("finds a violation at a nested field path", () => {
    const metas = metasFor({
      field: "input.fallbackOptions[1].value",
      description: "value is required",
    });

    assert.deepEqual(errorsAt(metas, "fallbackOptions[1].value"), ["is required"]);
    assert.deepEqual(errorsAt(metas, "fallbackOptions[0].value"), []);
  });

  it("finds a message-level violation on a list element", () => {
    const metas = metasFor({
      field: "input.fallbackOptions[0].conditions[1]",
      description: "a condition must name plans or a booth request",
    });

    assert.deepEqual(errorsAt(metas, "fallbackOptions[0].conditions[1]"), [
      "a condition must name plans or a booth request",
    ]);
  });

  it("numbers the violations of list items when asked", () => {
    const metas = metasFor(
      { field: "input.fallbackOptions[0].priorityHuman", description: "too many" },
      { field: "input.fallbackOptions[0].priorityHuman[1]", description: "too long" },
      { field: "input.fallbackOptions[0].priorityHumanNote", description: "unrelated" },
    );

    assert.deepEqual(errorsAt(metas, "fallbackOptions[0].priorityHuman", { items: true }), [
      "too many",
      "#2: too long",
    ]);
    assert.deepEqual(errorsAt(metas, "fallbackOptions[0].priorityHuman"), ["too many"]);
  });
});

describe("defaultLocale", () => {
  it("offers the locales FormDescriptionInput accepts", () => {
    assert.deepEqual(FORM_LOCALES, ["en", "ja"]);
  });

  it("picks the first locale not described yet", () => {
    assert.equal(defaultLocale([]), "en");
    assert.equal(defaultLocale(["en"]), "ja");
    assert.equal(defaultLocale(["ja", "en"]), "");
  });
});

describe("field paths", () => {
  const anchor = (path: string) => errorAnchor(path, FORM_DESCRIPTION_LAYOUT);
  const label = (path: string) => fieldLabel(path, FORM_DESCRIPTION_LAYOUT);

  it("show an error on a list of strings' element on the list", () => {
    assert.equal(anchor("fallbackOptions[0].priorityHuman[2]"), "fallbackOptions[0].priorityHuman");
    assert.equal(
      anchor("fallbackOptions[0].conditions[1].plans[0]"),
      "fallbackOptions[0].conditions[1].plans",
    );
    assert.equal(anchor("fallbackOptions[0].conditions[1]"), "fallbackOptions[0].conditions[1]");
    assert.equal(anchor("fallbackOptions[0]"), "fallbackOptions[0]");
  });

  it("are labelled as the editor labels their fields", () => {
    assert.equal(label("planHelp"), "Plan help");
    assert.equal(label("fallbackOptions"), "Fallback options");
    assert.equal(label("fallbackOptions[1].value"), "Option #2 › Value");
    assert.equal(
      label("fallbackOptions[0].conditions[2].boothRequest"),
      "Option #1 › Condition #3 › Booth",
    );
    assert.equal(label("fallbackOptions[0].priorityHuman[1]"), "Option #1 › Then, in order #2");
    assert.equal(label("unknownField"), "unknownField");
  });
});

describe("erroredFields", () => {
  it("lists errored fields in the editor's order, a list's element errors on the list", () => {
    const fields = erroredFields(
      {
        "fallbackOptions[1].value": { errors: ["is required"] },
        "fallbackOptions[0].priorityHuman[1]": { errors: ["must not be empty"] },
        "fallbackOptions[0].priorityHuman[0]": { errors: ["too long"] },
        "fallbackOptions[0].conditions[0]": {
          errors: ["a condition must name plans or a booth request"],
        },
        fallbackOptions: { errors: ["options sharing a value must differ in their conditions"] },
        head: { errors: [] },
        locale: { errors: [undefined, "value must be in list [en, ja]"] },
      },
      FORM_DESCRIPTION_LAYOUT,
    );

    assert.deepEqual(fields, [
      { path: "locale", label: "Locale", message: "value must be in list [en, ja]" },
      {
        path: "fallbackOptions",
        label: "Fallback options",
        message: "options sharing a value must differ in their conditions",
      },
      {
        path: "fallbackOptions[0].conditions[0]",
        label: "Option #1 › Condition #1",
        message: "a condition must name plans or a booth request",
      },
      {
        path: "fallbackOptions[0].priorityHuman",
        label: "Option #1 › Then, in order",
        message: "#1: too long",
      },
      { path: "fallbackOptions[1].value", label: "Option #2 › Value", message: "is required" },
    ]);
  });
});

describe("collisions", () => {
  const option = (value: string, plans: string[] = []): FallbackOptionValues => ({
    ...emptyFallbackOption(),
    value,
    conditions: plans.length === 0 ? [] : [{ plans, boothRequest: "any" }],
  });
  const options = [
    option("withdraw"),
    option("gold", ["Platinum"]),
    option("gold", ["Ruby"]),
    option("withdraw"),
    option("withdraw"),
  ];

  it("groups the options sharing a value and conditions", () => {
    assert.deepEqual(collidingOptions(options), [[0, 3, 4]]);
  });

  it("names the colliding options on the list and on each value", () => {
    const errors = withCollisions(
      { fields: { fallbackOptions: "options sharing a value must differ in their conditions" } },
      options,
    );

    assert.deepEqual(errors.fields, {
      fallbackOptions:
        'options sharing a value must differ in their conditions; #1, #4 and #5 share the value "withdraw" and their conditions',
      "fallbackOptions[0].value": "same value and conditions as #4 and #5",
      "fallbackOptions[3].value": "same value and conditions as #1 and #5",
      "fallbackOptions[4].value": "same value and conditions as #1 and #4",
    });
  });

  it("adds nothing when the server found no fault with the list", () => {
    const errors = { form: "Not saved", fields: { locale: "is required" } };

    assert.equal(withCollisions(errors, options), errors);
  });
});
