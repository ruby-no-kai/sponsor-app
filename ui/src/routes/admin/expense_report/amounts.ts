// Exact arithmetic on the decimal strings amounts and rates travel as, such as "120000.0" or
// "0.08", so a tax is rounded as the server rounds it rather than as a double would.

// A decimal as an integer count of 10^-scale.
type Fixed = { units: bigint; scale: number };

export function parseDecimal(value: string): Fixed | undefined {
  const match = /^(-?)(\d+)(?:\.(\d+))?$/.exec(value.trim());
  if (match === null) return undefined;
  const [, sign = "", integer = "", fraction = ""] = match;
  const units = BigInt(integer + fraction);
  return { units: sign === "-" ? -units : units, scale: fraction.length };
}

const pow10 = (exponent: number) => 10n ** BigInt(exponent);

function atScale({ units, scale }: Fixed, target: number): bigint {
  return units * pow10(target - scale);
}

// Units of 10^-scale as a plain decimal string, such as "-12.50".
function toDecimalString(units: bigint, scale: number): string {
  const sign = units < 0n ? "-" : "";
  const digits = (units < 0n ? -units : units).toString().padStart(scale + 1, "0");
  const integer = digits.slice(0, digits.length - scale);
  return scale === 0 ? `${sign}${integer}` : `${sign}${integer}.${digits.slice(-scale)}`;
}

// Division rounding toward negative and positive infinity, for a positive divisor.
function divideFloor(dividend: bigint, divisor: bigint): bigint {
  const quotient = dividend / divisor;
  return dividend % divisor !== 0n && dividend < 0n ? quotient - 1n : quotient;
}

function divideCeil(dividend: bigint, divisor: bigint): bigint {
  const quotient = dividend / divisor;
  return dividend % divisor !== 0n && dividend > 0n ? quotient + 1n : quotient;
}

function combine(a: string, b: string, op: (x: bigint, y: bigint) => bigint): string | undefined {
  const [x, y] = [parseDecimal(a), parseDecimal(b)];
  if (x === undefined || y === undefined) return undefined;
  const scale = Math.max(x.scale, y.scale);
  return toDecimalString(op(atScale(x, scale), atScale(y, scale)), scale);
}

export function addAmounts(a: string, b: string): string | undefined {
  return combine(a, b, (x, y) => x + y);
}

export function subtractAmounts(a: string, b: string): string | undefined {
  return combine(a, b, (x, y) => x - y);
}

// Whether two strings spell the same decimal, such as "5000" and "5000.0".
export function sameAmount(a: string, b: string): boolean {
  if (a === b) return true;
  const [x, y] = [parseDecimal(a), parseDecimal(b)];
  if (x === undefined || y === undefined) return false;
  const scale = Math.max(x.scale, y.scale);
  return atScale(x, scale) === atScale(y, scale);
}

// amount × rate rounded down to `digits` decimal places, as ExpenseLineItem calculates its tax.
export function taxOn(amount: string, rate: string, digits: number): string | undefined {
  const [x, r] = [parseDecimal(amount), parseDecimal(rate)];
  if (x === undefined || r === undefined) return undefined;
  const units = divideFloor(x.units * r.units * pow10(digits), pow10(x.scale + r.scale));
  return toDecimalString(units, digits);
}

// The amount before tax that an amount including tax at rate came from, rounded up to `digits`
// decimal places.
export function amountBeforeTax(amount: string, rate: string, digits: number): string | undefined {
  const [x, r] = [parseDecimal(amount), parseDecimal(rate)];
  if (x === undefined || r === undefined) return undefined;
  const units = divideCeil(
    x.units * pow10(r.scale) * pow10(digits),
    pow10(x.scale) * (pow10(r.scale) + r.units),
  );
  return toDecimalString(units, digits);
}

// An amount for an input: at least `digits` decimal places, and no trailing zeros past them.
export function amountToInput(amount: string, digits: number): string {
  const value = parseDecimal(amount);
  if (value === undefined) return amount;
  const scale = Math.max(value.scale, digits);
  let text = toDecimalString(atScale(value, scale), scale);
  for (let excess = scale - digits; excess > 0 && text.endsWith("0"); excess--) {
    text = text.slice(0, -1);
  }
  return text.endsWith(".") ? text.slice(0, -1) : text;
}

// For display in the browser's locale, rounded to `digits` decimal places, such as "120,000".
export function formatAmountAt(amount: string, digits: number, locale?: string): string {
  if (parseDecimal(amount) === undefined) return amount;
  return new Intl.NumberFormat(locale, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(amount.trim() as `${number}`);
}

// A rate as a percentage, such as "8%" for "0.08".
export function formatRate(rate: string): string {
  const value = parseDecimal(rate);
  if (value === undefined) return rate;
  return `${amountToInput(toDecimalString(value.units * 100n, value.scale), 0)}%`;
}
