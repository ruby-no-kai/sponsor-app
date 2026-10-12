import { matchPath } from "react-router";

// Every path the SPA renders. The router, the dev proxy and AppLink all read this list, so a path
// missing here is proxied to Rails and gets its HAML page.
export const paths = {
  // Conferences
  admin: "/admin",
  conferences: "/admin/conferences",
  conferenceNew: "/admin/conferences/new",
  conference: "/admin/conferences/:slug",
  conferenceEdit: "/admin/conferences/:slug/edit",
  attendeesKeeper: "/admin/conferences/:slug/attendees_keeper",
  sponsorshipTable: "/admin/conferences/:slug/table_view",

  // Form descriptions
  formDescriptionNew: "/admin/conferences/:slug/form_descriptions/new",
  formDescription: "/admin/conferences/:slug/form_descriptions/:locale",
  formDescriptionEdit: "/admin/conferences/:slug/form_descriptions/:locale/edit",

  // Plans
  plans: "/admin/conferences/:slug/plans",
  planNew: "/admin/conferences/:slug/plans/new",
  planEdit: "/admin/conferences/:slug/plans/:id/edit",

  // Sponsorships
  sponsorship: "/admin/conferences/:slug/sponsorships/:id",
  sponsorshipEdit: "/admin/conferences/:slug/sponsorships/:id/edit",

  // Organizations

  // Booth assignments

  // Sponsor events

  // Announcements

  // Broadcasts

  // Expense reports

  // Sponsor: Translations

  // Sponsor: Applications

  // Sponsor: Exhibitions and events

  // Sponsor: Broadcasts and passes

  // Sponsor: Expense reports
} as const;

const SPA_PATHS: readonly string[] = Object.values(paths);

// HAML pages that a pattern above would otherwise match. Drop an entry once the SPA renders it.
const RAILS_PATHS: readonly string[] = [];

const matches = (patterns: readonly string[], pathname: string) =>
  patterns.some((path) => matchPath({ path, end: true }, pathname) !== null);

export function isSpaPathname(pathname: string): boolean {
  return !matches(RAILS_PATHS, pathname) && matches(SPA_PATHS, pathname);
}

// Whether following href stays in the SPA: same origin, and a path listed above.
export function matchSpaPath(href: string, base: string = window.location.href): boolean {
  let url: URL;
  try {
    url = new URL(href, base);
  } catch {
    return false;
  }
  return url.origin === new URL(base).origin && isSpaPathname(url.pathname);
}
