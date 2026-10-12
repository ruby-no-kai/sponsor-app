import type { MessageInitShape } from "@bufbuild/protobuf";
import type {
  AdminPlan,
  PlanInputSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_plans_pb.ts";
import {
  int32ToInput,
  optionalFromInput,
  optionalInt32FromInput,
  optionalInt32ToInput,
  optionalToInput,
  timestampFromInput,
  timestampToInput,
} from "../../lib/forms.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";

// Named after PlanInput's JSON fields, so a google.rpc.BadRequest field path below "input." is
// the name of the form field it concerns.
export type PlanValues = {
  name: string;
  rank: string;
  summary: string;
  priceText: string;
  price: string;
  priceBooth: string;
  capacity: string;
  numberOfGuests: string;
  boothSize: string;
  wordsLimit: string;
  autoAcceptance: boolean;
  talkable: boolean;
  closesAt: string;
};

// What the editor labels each field, in the order it lays them out.
export const FIELD_LABELS: Readonly<Record<keyof PlanValues, string>> = {
  name: "Name",
  summary: "Summary",
  rank: "Rank",
  priceText: "Price as shown",
  price: "Fee",
  priceBooth: "Booth fee",
  capacity: "Capacity",
  numberOfGuests: "Guests",
  boothSize: "Booth size",
  wordsLimit: "Words limit",
  talkable: "Includes a sponsor session",
  closesAt: "Closes at",
  autoAcceptance: "Accept applications as soon as they are submitted",
};

export const PLAN_LAYOUT: FieldLayout = { labels: FIELD_LABELS };

// The values held as text, which are every one but the checkboxes.
export type PlanTextField = {
  [K in keyof PlanValues]: PlanValues[K] extends string ? K : never;
}[keyof PlanValues];

export type PlanInputInit = MessageInitShape<typeof PlanInputSchema>;

export type PlanInputResult =
  | { kind: "ok"; input: PlanInputInit }
  | { kind: "invalid"; fields: Record<string, string> };

// A new plan starts from the plans table's column defaults.
export function planValuesFrom(plan: AdminPlan | undefined): PlanValues {
  if (plan === undefined) {
    return {
      name: "",
      rank: "0",
      summary: "",
      priceText: "",
      price: "0",
      priceBooth: "0",
      capacity: "",
      numberOfGuests: "0",
      boothSize: "",
      wordsLimit: "",
      autoAcceptance: true,
      talkable: false,
      closesAt: "",
    };
  }
  return {
    name: plan.name,
    rank: int32ToInput(plan.rank),
    summary: optionalToInput(plan.summary),
    priceText: plan.priceText,
    price: plan.price,
    priceBooth: plan.priceBooth,
    capacity: int32ToInput(plan.capacity),
    numberOfGuests: int32ToInput(plan.numberOfGuests),
    boothSize: optionalInt32ToInput(plan.boothSize),
    wordsLimit: int32ToInput(plan.wordsLimit),
    autoAcceptance: plan.autoAcceptance,
    talkable: plan.talkable,
    closesAt: timestampToInput(plan.closesAt),
  };
}

const WHOLE_NUMBER = "Enter a whole number";

// Every rule is the server's, which reports an emptied number as missing. Only a value the message
// cannot carry, such as 1.5 guests, is reported here, as it never reaches the server.
export function planInputFrom(values: PlanValues): PlanInputResult {
  const fields: Record<string, string> = {};
  function read<T>(
    name: PlanTextField,
    from: (value: string) => T,
    fallback: T,
    message: string,
  ): T {
    try {
      return from(values[name]);
    } catch (error) {
      if (!(error instanceof RangeError)) throw error;
      fields[name] = message;
      return fallback;
    }
  }

  const input: PlanInputInit = {
    name: values.name,
    rank: read("rank", optionalInt32FromInput, undefined, WHOLE_NUMBER),
    summary: optionalFromInput(values.summary),
    priceText: values.priceText,
    price: values.price,
    priceBooth: values.priceBooth,
    capacity: read("capacity", optionalInt32FromInput, undefined, WHOLE_NUMBER),
    numberOfGuests: read("numberOfGuests", optionalInt32FromInput, undefined, WHOLE_NUMBER),
    boothSize: read("boothSize", optionalInt32FromInput, undefined, WHOLE_NUMBER),
    wordsLimit: read("wordsLimit", optionalInt32FromInput, undefined, WHOLE_NUMBER),
    autoAcceptance: values.autoAcceptance,
    talkable: values.talkable,
    closesAt: read("closesAt", timestampFromInput, undefined, "Enter a date and time"),
  };
  return Object.keys(fields).length === 0 ? { kind: "ok", input } : { kind: "invalid", fields };
}
