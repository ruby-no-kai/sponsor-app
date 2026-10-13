import { getOption } from "@bufbuild/protobuf";
import type { MessageInitShape } from "@bufbuild/protobuf";
import { field as fieldRules } from "../../gen/buf/validate/validate_pb.ts";
import { FormDescriptionInputSchema } from "../../gen/rubykaigi/sponsor_app/admin_form_descriptions_pb.ts";
import type {
  FallbackOption,
  FormDescription,
} from "../../gen/rubykaigi/sponsor_app/form_description_pb.ts";
import type { FormErrors } from "../../lib/errors.ts";
import type { FieldLayout, FieldMetas } from "../../lib/fieldErrors.ts";

// FallbackOption.Condition's optional booth_request as a select value, where "any" is unset.
export type BoothRequest = "any" | "requested" | "not_requested";

export type ConditionValues = { plans: string[]; boothRequest: BoothRequest };

export type FallbackOptionValues = {
  value: string;
  name: string;
  conditions: ConditionValues[];
  priorityHuman: string[];
};

// Named after FormDescriptionInput's JSON fields, so a google.rpc.BadRequest field path below
// "input." is the name of the form field it concerns.
export type FormDescriptionValues = {
  locale: string;
  head: string;
  planHelp: string;
  boothHelp: string;
  policyHelp: string;
  ticketHelp: string;
  sponsorEventHelp: string;
  eventPolicy: string;
  fallbackOptions: FallbackOptionValues[];
};

export type MarkdownField = {
  name: Exclude<keyof FormDescriptionValues, "locale" | "fallbackOptions">;
  label: string;
  html: keyof FormDescription & `${string}Html`;
};

export const MARKDOWN_FIELDS: readonly MarkdownField[] = [
  { name: "head", label: "Introduction", html: "headHtml" },
  { name: "planHelp", label: "Plan help", html: "planHelpHtml" },
  { name: "boothHelp", label: "Booth help", html: "boothHelpHtml" },
  { name: "policyHelp", label: "Policies", html: "policyHelpHtml" },
  { name: "ticketHelp", label: "Ticket help", html: "ticketHelpHtml" },
  { name: "sponsorEventHelp", label: "Sponsor event help", html: "sponsorEventHelpHtml" },
  { name: "eventPolicy", label: "Sponsor event policy", html: "eventPolicyHtml" },
];

// What the editor labels each field, by the last name of its path.
export const FIELD_LABELS = {
  locale: "Locale",
  fallbackOptions: "Fallback options",
  value: "Value",
  name: "Name",
  conditions: "Conditions",
  plans: "Plans applied for",
  boothRequest: "Booth",
  priorityHuman: "Then, in order",
} as const;

// The editor's fields in the order it lays them out, and the lists it lays out as cards of fields.
export const FORM_DESCRIPTION_LAYOUT: FieldLayout = {
  labels: {
    locale: FIELD_LABELS.locale,
    ...Object.fromEntries(MARKDOWN_FIELDS.map(({ name, label }) => [name, label])),
    fallbackOptions: FIELD_LABELS.fallbackOptions,
    value: FIELD_LABELS.value,
    name: FIELD_LABELS.name,
    conditions: FIELD_LABELS.conditions,
    plans: FIELD_LABELS.plans,
    boothRequest: FIELD_LABELS.boothRequest,
    priorityHuman: FIELD_LABELS.priorityHuman,
  },
  elements: { fallbackOptions: "Option", conditions: "Condition" },
};

// The locales FormDescriptionInput accepts, as its buf.validate rules list them.
export const FORM_LOCALES: readonly string[] = (() => {
  const rules = getOption(FormDescriptionInputSchema.field.locale, fieldRules);
  return rules.type.case === "string" ? rules.type.value.in : [];
})();

// The first locale the conference has no form description in, or none when it has them all.
export function defaultLocale(describedLocales: readonly string[]): string {
  return FORM_LOCALES.find((locale) => !describedLocales.includes(locale)) ?? "";
}

export const BOOTH_REQUEST_LABELS: Readonly<Record<BoothRequest, string>> = {
  any: "Either",
  requested: "Requested",
  not_requested: "Not requested",
};

export function isBoothRequest(value: unknown): value is BoothRequest {
  return typeof value === "string" && Object.hasOwn(BOOTH_REQUEST_LABELS, value);
}

export function boothRequestToInput(boothRequest: boolean | undefined): BoothRequest {
  if (boothRequest === undefined) return "any";
  return boothRequest ? "requested" : "not_requested";
}

export function boothRequestFromInput(value: BoothRequest): boolean | undefined {
  if (value === "any") return undefined;
  return value === "requested";
}

export function emptyCondition(): ConditionValues {
  return { plans: [], boothRequest: "any" };
}

export function emptyFallbackOption(): FallbackOptionValues {
  return { value: "", name: "", conditions: [], priorityHuman: [] };
}

function fallbackOptionValues(option: FallbackOption): FallbackOptionValues {
  return {
    value: option.value,
    name: option.name,
    conditions: option.conditions.map((condition) => ({
      plans: [...condition.plans],
      boothRequest: boothRequestToInput(condition.boothRequest),
    })),
    priorityHuman: [...option.priorityHuman],
  };
}

// A new form description starts empty, in the locale given.
export function formValuesFrom(
  formDescription: FormDescription | undefined,
  locale = "",
): FormDescriptionValues {
  return {
    locale: formDescription?.locale ?? locale,
    head: formDescription?.head ?? "",
    planHelp: formDescription?.planHelp ?? "",
    boothHelp: formDescription?.boothHelp ?? "",
    policyHelp: formDescription?.policyHelp ?? "",
    ticketHelp: formDescription?.ticketHelp ?? "",
    sponsorEventHelp: formDescription?.sponsorEventHelp ?? "",
    eventPolicy: formDescription?.eventPolicy ?? "",
    fallbackOptions: formDescription?.fallbackOptions.map(fallbackOptionValues) ?? [],
  };
}

export function inputFrom(
  values: FormDescriptionValues,
): MessageInitShape<typeof FormDescriptionInputSchema> {
  return {
    ...values,
    fallbackOptions: values.fallbackOptions.map((option) => ({
      ...option,
      conditions: option.conditions.map(({ plans, boothRequest }) => ({
        plans,
        boothRequest: boothRequestFromInput(boothRequest),
      })),
    })),
  };
}

// The conference's plans, then any plan a condition names that the conference does not have, so
// the editor shows a stale name rather than dropping it unseen. The server rejects such a name.
export function planChoices(planNames: readonly string[], selected: readonly string[]): string[] {
  return [...planNames, ...selected.filter((name) => !planNames.includes(name))];
}

// Moves the element at `from` by `offset` places, or returns undefined at either end.
export function movedIndex(from: number, offset: -1 | 1, length: number): number | undefined {
  const to = from + offset;
  return to < 0 || to >= length ? undefined : to;
}

const escapeRegExp = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// Error messages on a path, and with items on the elements of the list it names, such as
// `priorityHuman[1]`, which have no form field of their own.
export function errorsAt(
  fieldMeta: FieldMetas,
  path: string,
  { items = false }: { items?: boolean } = {},
): string[] {
  const itemPath = new RegExp(`^${escapeRegExp(path)}\\[(\\d+)\\]$`);
  return Object.entries(fieldMeta).flatMap(([name, meta]) => {
    const messages = (meta?.errors ?? []).filter(
      (error): error is string => typeof error === "string",
    );
    if (name === path) return messages;
    const item = items ? itemPath.exec(name) : null;
    return item === null ? [] : messages.map((message) => `#${Number(item[1]) + 1}: ${message}`);
  });
}

// Positions of the options that share a value and conditions, one list per group of them.
export function collidingOptions(options: readonly FallbackOptionValues[]): number[][] {
  const groups = new Map<string, number[]>();
  options.forEach(({ value, conditions }, index) => {
    const key = JSON.stringify([value, conditions]);
    groups.set(key, [...(groups.get(key) ?? []), index]);
  });
  return [...groups.values()].filter((group) => group.length > 1);
}

// "#1, #3 and #4"
function positions(indices: readonly number[]): string {
  const names = indices.map((index) => `#${index + 1}`);
  const last = names.pop();
  return names.length === 0 ? (last ?? "") : `${names.join(", ")} and ${last}`;
}

const appended = (existing: string | undefined, message: string) =>
  existing === undefined ? message : `${existing}; ${message}`;

// The server rejects options sharing a value and conditions as a whole list, so the options that
// collide are named here, on the list and on each one's value.
export function withCollisions(
  errors: FormErrors,
  options: readonly FallbackOptionValues[],
): FormErrors {
  if (errors.fields.fallbackOptions === undefined) return errors;

  const fields = { ...errors.fields };
  for (const group of collidingOptions(options)) {
    const value = options[group[0] ?? 0]?.value ?? "";
    fields.fallbackOptions = appended(
      fields.fallbackOptions,
      `${positions(group)} share the value "${value}" and their conditions`,
    );
    for (const index of group) {
      const path = `fallbackOptions[${index}].value`;
      const others = group.filter((other) => other !== index);
      fields[path] = appended(fields[path], `same value and conditions as ${positions(others)}`);
    }
  }
  return { ...errors, fields };
}
