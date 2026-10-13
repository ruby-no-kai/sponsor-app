import type { MessageInitShape } from "@bufbuild/protobuf";
import type {
  ExpenseLineItem,
  ExpenseLineItemInputSchema,
} from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";
import { optionalFromInput, optionalToInput } from "../../lib/forms.ts";
import { amountBeforeTax, amountToInput, sameAmount, subtractAmounts, taxOn } from "./amounts.ts";
import type { EditorText } from "./text.ts";

export type LineItemInputInit = MessageInitShape<typeof ExpenseLineItemInputSchema>;

// How the amount entered is read. Including and excluding tax both store the amount before tax
// with the rate, so they differ only in what the editor asks for.
export type TaxMode = "exclude" | "include" | "exempt" | "manual";

export function taxModes(text: EditorText): readonly { value: TaxMode; label: string }[] {
  return [
    { value: "exclude", label: text("tax_mode_exclude") },
    { value: "include", label: text("tax_mode_include") },
    { value: "exempt", label: text("tax_mode_exempt") },
    { value: "manual", label: text("tax_mode_manual") },
  ];
}

// What the editor reads as a line item's stored values imply: no rate is a tax entered by hand.
export function taxModeOf(taxRate: string | undefined): TaxMode {
  if (taxRate === undefined) return "manual";
  return sameAmount(taxRate, "0") ? "exempt" : "exclude";
}

// The figures the calculation gives an editor.
export type Rounding = { taxRates: readonly string[]; decimal: number };

// Named after ExpenseLineItemInput's JSON fields, so a google.rpc.BadRequest field path below
// "input." is the name of the form field it concerns. taxMode alone is the editor's own.
export type LineItemValues = {
  title: string;
  notes: string;
  taxMode: TaxMode;
  taxRate: string;
  // As entered: including tax in the include mode.
  amount: string;
  // Read only in the manual mode.
  taxAmount: string;
  preliminal: boolean;
  fileIds: string[];
};

export function fieldLabels(text: EditorText): Readonly<Record<keyof LineItemValues, string>> {
  return {
    title: text("title_label"),
    notes: text("notes_label"),
    taxMode: text("tax_mode_label"),
    taxRate: text("tax_rate_label"),
    amount: text("amount_label"),
    taxAmount: text("tax_amount_label"),
    preliminal: text("preliminal_badge"),
    fileIds: text("attached_files"),
  };
}

export function lineItemLayout(text: EditorText): FieldLayout {
  return { labels: fieldLabels(text) };
}

// The configured rate a stored one equals, as the select offers it, such as "0.1" for "0.1000".
export function rateOption(rates: readonly string[], rate: string): string {
  return rates.find((option) => sameAmount(option, rate)) ?? rate;
}

export function lineItemValuesFrom(item: ExpenseLineItem, rounding: Rounding): LineItemValues {
  const taxMode = taxModeOf(item.taxRate);
  return {
    title: item.title,
    notes: optionalToInput(item.notes),
    taxMode,
    taxRate:
      taxMode === "exclude" && item.taxRate !== undefined
        ? rateOption(rounding.taxRates, item.taxRate)
        : (rounding.taxRates[0] ?? ""),
    amount: amountToInput(item.amount, rounding.decimal),
    taxAmount: amountToInput(item.taxAmount, rounding.decimal),
    preliminal: item.preliminal,
    fileIds: item.fileIds,
  };
}

export type StoredAmounts = { amount: string; taxAmount: string; taxRate?: string };

// What the line item stores for the amount entered. An entry that is no decimal goes as it is,
// for the server to refuse on its field.
export function storedAmounts(
  values: Pick<LineItemValues, "taxMode" | "taxRate" | "amount" | "taxAmount">,
  decimal: number,
): StoredAmounts {
  const { amount, taxRate } = values;
  switch (values.taxMode) {
    case "manual":
      return { amount, taxAmount: values.taxAmount };
    case "exempt":
      return { amount, taxAmount: "0", taxRate: "0" };
    case "exclude":
      return { amount, taxAmount: taxOn(amount, taxRate, decimal) ?? "0", taxRate };
    case "include": {
      // Receipts round the tax on the amount before tax down, so that amount is rounded up.
      const before = amountBeforeTax(amount, taxRate, decimal);
      if (before === undefined) return { amount, taxAmount: "0", taxRate };
      return { amount: before, taxAmount: subtractAmounts(amount, before) ?? "0", taxRate };
    }
  }
}

export function lineItemInputFrom(values: LineItemValues, decimal: number): LineItemInputInit {
  return {
    title: values.title,
    notes: optionalFromInput(values.notes),
    ...storedAmounts(values, decimal),
    preliminal: values.preliminal,
    fileIds: values.fileIds,
  };
}

// Every writable field as stored, for an RPC replacing them all to change one or two.
export function lineItemInputOf(item: ExpenseLineItem): LineItemInputInit {
  return {
    title: item.title,
    notes: item.notes,
    amount: item.amount,
    taxRate: item.taxRate,
    taxAmount: item.taxAmount,
    preliminal: item.preliminal,
    fileIds: item.fileIds,
  };
}

// A line item to fill in afterwards, attaching files.
export function newLineItemInput(
  title: string,
  fileIds: readonly string[] = [],
): LineItemInputInit {
  return { title, amount: "0", taxAmount: "0", fileIds: [...fileIds] };
}

// Whether saving the values would change what the line item stores.
export function isLineItemChanged(
  values: LineItemValues,
  item: ExpenseLineItem,
  decimal: number,
): boolean {
  const stored = storedAmounts(values, decimal);
  const savedMode = taxModeOf(item.taxRate);
  const modeChanged =
    values.taxMode !== savedMode && !(values.taxMode === "include" && savedMode === "exclude");
  return (
    values.title !== item.title ||
    values.notes !== optionalToInput(item.notes) ||
    values.preliminal !== item.preliminal ||
    values.fileIds.join(",") !== item.fileIds.join(",") ||
    !sameAmount(stored.amount, item.amount) ||
    modeChanged ||
    ((values.taxMode === "exclude" || values.taxMode === "include") &&
      !sameAmount(values.taxRate, item.taxRate ?? "")) ||
    (values.taxMode === "manual" && !sameAmount(values.taxAmount, item.taxAmount))
  );
}

// Where a line item dragged onto another lands: that one's place, 1 being the first, and the
// order the list shows until the server answers.
export function moveLineItem<T extends { id: string }>(
  items: readonly T[],
  movedId: string,
  overId: string,
): { place: number; items: T[] } | undefined {
  const from = items.findIndex((item) => item.id === movedId);
  const to = items.findIndex((item) => item.id === overId);
  const moved = items[from];
  if (moved === undefined || to === -1 || from === to) return undefined;
  const reordered = items.filter((item) => item.id !== movedId);
  reordered.splice(to, 0, moved);
  return { place: to + 1, items: reordered };
}
