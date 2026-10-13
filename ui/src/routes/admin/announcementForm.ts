import { getOption } from "@bufbuild/protobuf";
import type { MessageInitShape } from "@bufbuild/protobuf";
import { generatePath } from "react-router";
import { field as fieldRules } from "../../gen/buf/validate/validate_pb.ts";
import { AnnouncementInputSchema } from "../../gen/rubykaigi/sponsor_app/admin_announcements_pb.ts";
import type {
  AdminAnnouncement,
  AdminAnnouncementSummary,
} from "../../gen/rubykaigi/sponsor_app/admin_announcements_pb.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";
import { paths } from "../paths.ts";

// The ID the HAML pages put in an announcement's path, so their links land on the same pages here.
export function announcementId(issue: string, locale: string): string {
  return `${issue}:${locale}`;
}

// Split at the first colon, as the HAML pages split it. Undefined when either part is empty.
export function parseAnnouncementId(id: string): { issue: string; locale: string } | undefined {
  const at = id.indexOf(":");
  if (at <= 0 || at === id.length - 1) return undefined;
  return { issue: id.slice(0, at), locale: id.slice(at + 1) };
}

export function announcementPath(slug: string, issue: string, locale: string): string {
  return generatePath(paths.announcement, { slug, id: announcementId(issue, locale) });
}

export function announcementEditPath(slug: string, issue: string, locale: string): string {
  return generatePath(paths.announcementEdit, { slug, id: announcementId(issue, locale) });
}

// The new announcement page, writing another locale of the issue when one is given.
export function announcementNewPath(slug: string, issue?: string): string {
  const path = generatePath(paths.announcementNew, { slug });
  return issue === undefined ? path : `${path}?${new URLSearchParams({ issue }).toString()}`;
}

// Named after AnnouncementInput's JSON fields, so a google.rpc.BadRequest field path below
// "input." is the name of the form field it concerns.
export type AnnouncementValues = {
  locale: string;
  title: string;
  body: string;
  pinned: boolean;
  exhibitorsOnly: boolean;
  published: boolean;
  newRevision: boolean;
};

// What the editor labels each field, in the order it lays them out.
export const FIELD_LABELS: Readonly<Record<keyof AnnouncementValues, string>> = {
  locale: "Locale",
  title: "Title",
  body: "Body",
  pinned: "Pin",
  exhibitorsOnly: "Exhibitors only",
  published: "Publish",
  newRevision: "Request translation",
};

export const ANNOUNCEMENT_LAYOUT: FieldLayout = { labels: FIELD_LABELS };

// The locales AnnouncementInput accepts, as its buf.validate rules list them.
export const ANNOUNCEMENT_LOCALES: readonly string[] = (() => {
  const rules = getOption(AnnouncementInputSchema.field.locale, fieldRules);
  return rules.type.case === "string" ? rules.type.value.in : [];
})();

// The first locale an issue is not written in, or none when it is written in every one.
export function defaultLocale(writtenLocales: readonly string[]): string {
  return ANNOUNCEMENT_LOCALES.find((locale) => !writtenLocales.includes(locale)) ?? "";
}

// The locales the editor offers, each one the issue is already written in marked as such. A
// stored locale outside the accepted ones stays listed, so the form shows what is saved.
export function localeItems(
  writtenLocales: readonly string[],
  current: string,
): { label: string; value: string }[] {
  const locales =
    ANNOUNCEMENT_LOCALES.includes(current) || current === ""
      ? ANNOUNCEMENT_LOCALES
      : [...ANNOUNCEMENT_LOCALES, current];
  return locales.map((locale) => ({
    label: locale !== current && writtenLocales.includes(locale) ? `${locale} (written)` : locale,
    value: locale,
  }));
}

// Request translation starts unchecked on every edit. A new locale of an issue starts from the
// visibility of the issue's other locales, as a translation is read by the same sponsors.
export function announcementValuesFrom(
  saved: AdminAnnouncement | undefined,
  { locale = "", sibling }: { locale?: string; sibling?: AdminAnnouncementSummary } = {},
): AnnouncementValues {
  if (saved === undefined) {
    return {
      locale,
      title: "",
      body: "",
      pinned: sibling?.pinned ?? false,
      exhibitorsOnly: sibling?.exhibitorsOnly ?? false,
      published: false,
      newRevision: false,
    };
  }
  return {
    locale: saved.locale,
    title: saved.title,
    body: saved.body,
    pinned: saved.pinned,
    exhibitorsOnly: saved.exhibitorsOnly,
    published: saved.published,
    newRevision: false,
  };
}

export function announcementInputFrom(
  values: AnnouncementValues,
): MessageInitShape<typeof AnnouncementInputSchema> {
  return {
    locale: values.locale,
    title: values.title,
    body: values.body,
    pinned: values.pinned,
    exhibitorsOnly: values.exhibitorsOnly,
    published: values.published,
    newRevision: values.newRevision,
  };
}
