import { timestampDate } from "@bufbuild/protobuf/wkt";
import type { Timestamp } from "@bufbuild/protobuf/wkt";

const dateFormat = new Intl.DateTimeFormat(undefined, {
  year: "numeric",
  month: "short",
  day: "numeric",
});

const venueDateFormat = new Intl.DateTimeFormat(undefined, {
  year: "numeric",
  month: "short",
  day: "numeric",
  timeZone: "UTC",
});

const dateTimeFormat = new Intl.DateTimeFormat(undefined, {
  year: "numeric",
  month: "short",
  day: "numeric",
  hour: "numeric",
  minute: "2-digit",
});

// A moment for display without a zone, such as "Sep 13, 2026, 10:30 AM", in the browser's locale
// and time zone.
export function formatDateTime(timestamp: Timestamp | undefined, unset = "—"): string {
  return timestamp === undefined ? unset : dateTimeFormat.format(timestampDate(timestamp));
}

// A day for display, such as "Sep 13, 2026", in the browser's locale and time zone.
export function formatDate(timestamp: Timestamp | undefined, unset = "—"): string {
  return timestamp === undefined ? unset : dateFormat.format(timestampDate(timestamp));
}

// A day at the venue, such as "Sep 13, 2026", read from the UTC fields the timestamp carries.
export function formatVenueDate(timestamp: Timestamp | undefined, unset = "—"): string {
  return timestamp === undefined ? unset : venueDateFormat.format(timestampDate(timestamp));
}

// "Sep 13, 2026 – Nov 13, 2026", or one side with its own unset text when the other is missing.
export function formatDateRange(
  from: Timestamp | undefined,
  to: Timestamp | undefined,
  unset: { from: string; to: string } = { from: "—", to: "—" },
): string {
  return `${formatDate(from, unset.from)} – ${formatDate(to, unset.to)}`;
}
