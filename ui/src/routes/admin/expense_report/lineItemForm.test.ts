import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toJson } from "@bufbuild/protobuf";
import {
  ExpenseLineItemInputSchema,
  ExpenseLineItemSchema,
} from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import {
  isLineItemChanged,
  lineItemInputFrom,
  lineItemInputOf,
  lineItemValuesFrom,
  moveLineItem,
  newLineItemInput,
  rateOption,
  storedAmounts,
  taxModeOf,
} from "./lineItemForm.ts";
import type { LineItemInputInit, LineItemValues } from "./lineItemForm.ts";

const rounding = { taxRates: ["0.1", "0.08", "0.0"], decimal: 0 };

const venue = create(ExpenseLineItemSchema, {
  id: "7",
  title: "Venue",
  notes: "Hall A",
  amount: "5000.0",
  taxRate: "0.1",
  taxAmount: "500.0",
  preliminal: true,
  position: 2,
  fileIds: ["3", "1"],
});

function inputJson(input: LineItemInputInit) {
  return toJson(ExpenseLineItemInputSchema, create(ExpenseLineItemInputSchema, input));
}

function values(overrides: Partial<LineItemValues> = {}): LineItemValues {
  return { ...lineItemValuesFrom(venue, rounding), ...overrides };
}

describe("taxModeOf", () => {
  it("reads the mode from the stored rate", () => {
    assert.equal(taxModeOf("0.1"), "exclude");
    assert.equal(taxModeOf("0.0"), "exempt");
    assert.equal(taxModeOf(undefined), "manual");
  });
});

describe("lineItemValuesFrom", () => {
  it("fills the editor from the stored line item", () => {
    assert.deepEqual(values(), {
      title: "Venue",
      notes: "Hall A",
      taxMode: "exclude",
      taxRate: "0.1",
      amount: "5000",
      taxAmount: "500",
      preliminal: true,
      fileIds: ["3", "1"],
    });
  });

  it("offers the first configured rate for a tax entered by hand", () => {
    const manual = create(ExpenseLineItemSchema, {
      ...venue,
      taxRate: undefined,
      notes: undefined,
    });

    assert.deepEqual(
      { ...lineItemValuesFrom(manual, rounding) },
      { ...values(), notes: "", taxMode: "manual", taxRate: "0.1" },
    );
  });

  it("matches a stored rate to the configured one it equals", () => {
    assert.equal(rateOption(rounding.taxRates, "0.0800"), "0.08");
    assert.equal(rateOption(rounding.taxRates, "0.05"), "0.05");
  });
});

describe("storedAmounts", () => {
  it("calculates the tax on an amount excluding it", () => {
    assert.deepEqual(storedAmounts(values({ amount: "999", taxRate: "0.08" }), 0), {
      amount: "999",
      taxAmount: "79",
      taxRate: "0.08",
    });
  });

  it("splits an amount including tax", () => {
    assert.deepEqual(storedAmounts(values({ taxMode: "include", amount: "1100" }), 0), {
      amount: "1000",
      taxAmount: "100",
      taxRate: "0.1",
    });
  });

  it("stores a zero rate when tax does not apply", () => {
    assert.deepEqual(storedAmounts(values({ taxMode: "exempt", taxAmount: "12" }), 0), {
      amount: "5000",
      taxAmount: "0",
      taxRate: "0",
    });
  });

  it("stores the tax as entered without a rate", () => {
    assert.deepEqual(storedAmounts(values({ taxMode: "manual", taxAmount: "123.45" }), 0), {
      amount: "5000",
      taxAmount: "123.45",
    });
  });

  it("sends an amount that is no decimal as it is, for the server to refuse", () => {
    assert.deepEqual(storedAmounts(values({ taxMode: "include", amount: "1,100" }), 0), {
      amount: "1,100",
      taxAmount: "0",
      taxRate: "0.1",
    });
  });
});

describe("lineItemInputFrom", () => {
  it("builds the input from the values", () => {
    assert.deepEqual(inputJson(lineItemInputFrom(values({ notes: "" }), 0)), {
      title: "Venue",
      amount: "5000",
      taxRate: "0.1",
      taxAmount: "500",
      preliminal: true,
      fileIds: ["3", "1"],
    });
  });

  it("copies a stored line item field for field", () => {
    assert.deepEqual(inputJson(lineItemInputOf(venue)), {
      title: "Venue",
      notes: "Hall A",
      amount: "5000.0",
      taxRate: "0.1",
      taxAmount: "500.0",
      preliminal: true,
      fileIds: ["3", "1"],
    });
  });

  it("starts a new line item at zero", () => {
    assert.deepEqual(inputJson(newLineItemInput("receipt.pdf", ["4"])), {
      title: "receipt.pdf",
      amount: "0",
      taxAmount: "0",
      fileIds: ["4"],
    });
  });
});

describe("isLineItemChanged", () => {
  it("is unchanged for the values the line item fills in", () => {
    assert.equal(isLineItemChanged(values(), venue, 0), false);
  });

  it("is unchanged by switching between including and excluding tax alone", () => {
    assert.equal(
      isLineItemChanged(values({ taxMode: "include", amount: "5500" }), venue, 0),
      false,
    );
  });

  it("is changed by any stored value", () => {
    const changes: Partial<LineItemValues>[] = [
      { title: "Hall" },
      { notes: "" },
      { preliminal: false },
      { fileIds: ["1", "3"] },
      { amount: "5001" },
      { taxRate: "0.08" },
      { taxMode: "exempt" },
      { taxMode: "manual" },
    ];
    for (const change of changes) {
      assert.equal(isLineItemChanged(values(change), venue, 0), true, JSON.stringify(change));
    }
  });
});

describe("moveLineItem", () => {
  const items = [{ id: "1" }, { id: "2" }, { id: "3" }];

  it("puts a line item dragged down after the one it lands on", () => {
    assert.deepEqual(moveLineItem(items, "1", "3"), {
      place: 3,
      items: [{ id: "2" }, { id: "3" }, { id: "1" }],
    });
  });

  it("puts a line item dragged up before the one it lands on", () => {
    assert.deepEqual(moveLineItem(items, "3", "2"), {
      place: 2,
      items: [{ id: "1" }, { id: "3" }, { id: "2" }],
    });
  });

  it("does nothing for a drop on itself or on an unknown item", () => {
    assert.equal(moveLineItem(items, "2", "2"), undefined);
    assert.equal(moveLineItem(items, "2", "9"), undefined);
  });
});
