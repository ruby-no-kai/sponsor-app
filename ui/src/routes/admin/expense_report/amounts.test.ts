import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  addAmounts,
  amountBeforeTax,
  amountToInput,
  formatAmountAt,
  formatRate,
  parseDecimal,
  sameAmount,
  subtractAmounts,
  taxOn,
} from "./amounts.ts";

describe("parseDecimal", () => {
  it("reads decimals as the server spells them", () => {
    assert.deepEqual(parseDecimal("120000.0"), { units: 1200000n, scale: 1 });
    assert.deepEqual(parseDecimal("-0.08"), { units: -8n, scale: 2 });
    assert.deepEqual(parseDecimal(" 12 "), { units: 12n, scale: 0 });
  });

  it("refuses what is no plain decimal", () => {
    for (const value of ["", "1,000", "1e3", "1.", ".5", "abc"]) {
      assert.equal(parseDecimal(value), undefined, value);
    }
  });
});

describe("arithmetic", () => {
  it("adds and subtracts without float drift", () => {
    assert.equal(addAmounts("0.1", "0.2"), "0.3");
    assert.equal(subtractAmounts("3500000.0", "120000"), "3380000.0");
    assert.equal(subtractAmounts("100", "120.5"), "-20.5");
    assert.equal(addAmounts("abc", "1"), undefined);
  });

  it("compares by value", () => {
    assert.ok(sameAmount("5000", "5000.00"));
    assert.ok(!sameAmount("5000", "5000.01"));
    assert.ok(!sameAmount("", "0"));
  });
});

describe("taxOn", () => {
  it("rounds the tax down as ExpenseLineItem does", () => {
    assert.equal(taxOn("1000", "0.1", 0), "100");
    assert.equal(taxOn("999", "0.08", 0), "79");
    assert.equal(taxOn("1234.56", "0.1", 2), "123.45");
    assert.equal(taxOn("1000", "0.0", 0), "0");
  });

  it("is exact where a double is not", () => {
    // 0.07 * 100 is 7.000000000000001 as a double.
    assert.equal(taxOn("100", "0.07", 0), "7");
    assert.equal(taxOn("1100", "0.1", 0), "110");
  });
});

describe("amountBeforeTax", () => {
  it("rounds up, so the tax rounded down from it adds back to at least the amount", () => {
    assert.equal(amountBeforeTax("1100", "0.1", 0), "1000");
    assert.equal(amountBeforeTax("1080", "0.08", 0), "1000");
    assert.equal(amountBeforeTax("1000", "0.08", 0), "926");
    assert.equal(amountBeforeTax("1000", "0.1", 2), "909.10");
  });

  it("answers undefined for an entry that is no decimal", () => {
    assert.equal(amountBeforeTax("", "0.1", 0), undefined);
  });
});

describe("amountToInput", () => {
  it("keeps the digits that matter and the configured places", () => {
    assert.equal(amountToInput("5000.0", 0), "5000");
    assert.equal(amountToInput("1234.50", 0), "1234.5");
    assert.equal(amountToInput("12", 2), "12.00");
    assert.equal(amountToInput("0.0", 0), "0");
    assert.equal(amountToInput("abc", 0), "abc");
  });
});

describe("formatAmountAt", () => {
  it("groups and rounds to the configured places", () => {
    assert.equal(formatAmountAt("3380000.0", 0, "en-US"), "3,380,000");
    assert.equal(formatAmountAt("-500000.0", 0, "en-US"), "-500,000");
    assert.equal(formatAmountAt("1234.5", 2, "en-US"), "1,234.50");
    assert.equal(formatAmountAt("9999999999.99", 2, "en-US"), "9,999,999,999.99");
  });

  it("shows what is no decimal as it is", () => {
    assert.equal(formatAmountAt("n/a", 0, "en-US"), "n/a");
  });
});

describe("formatRate", () => {
  it("shows a rate as a percentage", () => {
    assert.equal(formatRate("0.1"), "10%");
    assert.equal(formatRate("0.08"), "8%");
    assert.equal(formatRate("0.0"), "0%");
    assert.equal(formatRate("0.085"), "8.5%");
  });
});
