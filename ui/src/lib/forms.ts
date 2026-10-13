import { timestampDate, timestampFromDate } from "@bufbuild/protobuf/wkt";
import type { Timestamp } from "@bufbuild/protobuf/wkt";

// Converters between what form inputs hold, always strings, and the init shapes of Input messages.

// int64 IDs are bigint in messages.
export function idToInput(id: bigint): string {
  return id.toString();
}

export function idFromInput(value: string): bigint {
  if (!/^\d+$/.test(value)) throw new RangeError(`not an ID: ${JSON.stringify(value)}`);
  return BigInt(value);
}

// An `optional` string field is unset rather than empty.
export function optionalToInput(value: string | undefined): string {
  return value ?? "";
}

export function optionalFromInput(value: string): string | undefined {
  return value === "" ? undefined : value;
}

const INT32_MIN = -(2 ** 31);
const INT32_MAX = 2 ** 31 - 1;

// int32 fields. A number input holds "" both when empty and when what was typed is no number.
export function int32ToInput(value: number): string {
  return String(value);
}

export function int32FromInput(value: string): number {
  const trimmed = value.trim();
  const number = Number(trimmed);
  if (!/^-?\d+$/.test(trimmed) || number < INT32_MIN || number > INT32_MAX)
    throw new RangeError(`not an int32: ${JSON.stringify(value)}`);
  return number;
}

// An `optional` int32 field is unset rather than zero.
export function optionalInt32ToInput(value: number | undefined): string {
  return value === undefined ? "" : int32ToInput(value);
}

export function optionalInt32FromInput(value: string): number | undefined {
  return value.trim() === "" ? undefined : int32FromInput(value);
}

const pad = (n: number) => String(n).padStart(2, "0");

// The value of an <input type="datetime-local">, in the browser's time zone. Seconds appear only
// when set, as the input's default step is a minute.
export function timestampToInput(timestamp: Timestamp | undefined): string {
  if (timestamp === undefined) return "";
  const date = timestampDate(timestamp);
  const minutes = `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
  return date.getSeconds() === 0 ? minutes : `${minutes}:${pad(date.getSeconds())}`;
}

// ECMAScript reads a date-time without an offset as local time.
export function timestampFromInput(value: string): Timestamp | undefined {
  if (value === "") return undefined;
  const date = new Date(value);
  if (Number.isNaN(date.getTime()))
    throw new RangeError(`not a datetime-local value: ${JSON.stringify(value)}`);
  return timestampFromDate(date);
}

// dateStyle and timeStyle refuse timeZoneName, hence the components.
const timestampFormat = new Intl.DateTimeFormat(undefined, {
  year: "numeric",
  month: "short",
  day: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  timeZoneName: "short",
});

// For display, in the browser's locale and time zone.
export function formatTimestamp(timestamp: Timestamp | undefined, unset = "—"): string {
  return timestamp === undefined ? unset : timestampFormat.format(timestampDate(timestamp));
}
