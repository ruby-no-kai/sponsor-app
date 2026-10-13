import { getOption } from "@bufbuild/protobuf";
import type { MessageInitShape } from "@bufbuild/protobuf";
import { field as fieldRules } from "../../gen/buf/validate/validate_pb.ts";
import { FormDescriptionInputSchema } from "../../gen/rubykaigi/sponsor_app/admin_form_descriptions_pb.ts";
import type {
  FallbackOption,
  FormDescription,
} from "../../gen/rubykaigi/sponsor_app/form_description_pb.ts";
import type { FormErrors } from "../../lib/errors.ts";

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

// The names of field paths in the order the editor lays their fields out.
const FIELD_ORDER: readonly string[] = [
  "locale",
  ...MARKDOWN_FIELDS.map(({ name }) => name),
  "fallbackOptions",
  "value",
  "name",
  "conditions",
  "plans",
  "boothRequest",
  "priorityHuman",
];

// Lists whose elements the editor lays out as cards of fields, named by these.
const ELEMENT_LABELS: Readonly<Record<string, string>> = {
  fallbackOptions: "Option",
  conditions: "Condition",
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

type FieldMetas = Readonly<Record<string, { errors: readonly unknown[] } | undefined>>;

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

type PathSegment = string | number;

// `fallbackOptions[1].value` as ["fallbackOptions", 1, "value"].
function pathSegments(path: string): PathSegment[] {
  return Array.from(path.matchAll(/([^.[\]]+)|\[(\d+)\]/g), ([, name, index]) =>
    index === undefined ? (name ?? "") : Number(index),
  );
}

// The path one step up, such as `fallbackOptions[1]` for `fallbackOptions[1].value`.
export function parentPath(path: string): string | undefined {
  const at = Math.max(path.lastIndexOf("."), path.lastIndexOf("["));
  return at <= 0 ? undefined : path.slice(0, at);
}

// The path of the field an error on `path` shows on. An element of a list of strings, such as
// `priorityHuman[1]`, has no field of its own and shows on its list.
export function errorAnchor(path: string): string {
  const segments = pathSegments(path);
  const [owner, last] = segments.slice(-2);
  const ownsFields = typeof owner === "string" && Object.hasOwn(ELEMENT_LABELS, owner);
  return typeof last === "number" && !ownsFields ? (parentPath(path) ?? path) : path;
}

const LABELS: Readonly<Record<string, string>> = {
  ...Object.fromEntries(MARKDOWN_FIELDS.map(({ name, label }) => [name, label])),
  ...FIELD_LABELS,
};

// What the editor calls the field at a path, such as "Option #2 › Value".
export function fieldLabel(path: string): string {
  const labels: string[] = [];
  let owner: PathSegment | undefined;
  for (const segment of pathSegments(path)) {
    if (typeof segment === "string") {
      labels.push(LABELS[segment] ?? segment);
    } else {
      const element = typeof owner === "string" ? ELEMENT_LABELS[owner] : undefined;
      const last = labels.pop() ?? "";
      labels.push(element === undefined ? `${last} #${segment + 1}` : `${element} #${segment + 1}`);
    }
    owner = segment;
  }
  return labels.join(" › ");
}

function orderOf(segment: PathSegment | undefined): number {
  if (typeof segment !== "string") return -1;
  const at = FIELD_ORDER.indexOf(segment);
  return at === -1 ? FIELD_ORDER.length : at;
}

// Orders paths as the editor lays out their fields, a list's own errors before its elements'.
function comparePaths(a: PathSegment[], b: PathSegment[]): number {
  for (let at = 0; at < Math.min(a.length, b.length); at++) {
    const [x, y] = [a[at], b[at]];
    if (x === y) continue;
    if (typeof x === "number" && typeof y === "number") return x - y;
    return orderOf(x) - orderOf(y);
  }
  return a.length - b.length;
}

export type FieldError = { path: string; label: string; message: string };

// The fields showing an error, in the order the editor lays them out, each with its first message.
export function erroredFields(fieldMeta: FieldMetas): FieldError[] {
  const messages = Object.entries(fieldMeta)
    .flatMap(([name, meta]) => {
      const message = meta?.errors.find((error): error is string => typeof error === "string");
      return message === undefined ? [] : [{ name, segments: pathSegments(name), message }];
    })
    .sort((a, b) => comparePaths(a.segments, b.segments));

  const fields = new Map<string, FieldError>();
  for (const { name, segments, message } of messages) {
    const path = errorAnchor(name);
    if (fields.has(path)) continue;
    const item = segments.at(-1);
    fields.set(path, {
      path,
      label: fieldLabel(path),
      message: path === name || typeof item !== "number" ? message : `#${item + 1}: ${message}`,
    });
  }
  return [...fields.values()];
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
