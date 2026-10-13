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

// The ID a route parameter names, or undefined when it can name none.
export function idFromParam(param: string): bigint | undefined {
  try {
    return idFromInput(param);
  } catch (error) {
    if (error instanceof RangeError) return undefined;
    throw error;
  }
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

// The value a "Now" button puts into a datetime-local input, to the minute.
export function nowInput(now: Date = new Date()): string {
  const minute = new Date(now);
  minute.setSeconds(0, 0);
  return timestampToInput(timestampFromDate(minute));
}

// ECMAScript reads a date-time without an offset as local time.
export function timestampFromInput(value: string): Timestamp | undefined {
  if (value === "") return undefined;
  const date = new Date(value);
  if (Number.isNaN(date.getTime()))
    throw new RangeError(`not a datetime-local value: ${JSON.stringify(value)}`);
  return timestampFromDate(date);
}

// The value of an <input type="datetime-local"> for a time kept as the wall clock at the venue,
// which the Timestamp carries as the same reading in UTC. Seconds appear only when set.
export function venueTimeToInput(timestamp: Timestamp | undefined): string {
  if (timestamp === undefined) return "";
  const iso = timestampDate(timestamp).toISOString();
  const minutes = iso.slice(0, "YYYY-MM-DDTHH:MM".length);
  const seconds = iso.slice("YYYY-MM-DDTHH:MM:".length, "YYYY-MM-DDTHH:MM:SS".length);
  return seconds === "00" ? minutes : `${minutes}:${seconds}`;
}

const VENUE_TIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?$/;

// The Timestamp that reads the same as the input, in UTC whatever the browser's time zone is.
export function venueTimeFromInput(value: string): Timestamp | undefined {
  if (value === "") return undefined;
  const date = VENUE_TIME.test(value) ? new Date(`${value}Z`) : undefined;
  if (date === undefined || Number.isNaN(date.getTime()))
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

const venueTimestampFormat = new Intl.DateTimeFormat(undefined, {
  year: "numeric",
  month: "short",
  day: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  timeZone: "UTC",
});

// For display, in the browser's locale, as the wall clock at the venue: the UTC reading, no zone.
export function formatVenueTimestamp(timestamp: Timestamp | undefined, unset = "—"): string {
  return timestamp === undefined ? unset : venueTimestampFormat.format(timestampDate(timestamp));
}
