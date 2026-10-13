import { generatePath } from "react-router";
import type { Conference } from "../../gen/rubykaigi/sponsor_app/conference_pb.ts";
import type { SponsorViewer } from "../../gen/rubykaigi/sponsor_app/sponsor_viewer_pb.ts";
import { signInUrl } from "../../lib/rpc.ts";
import { paths } from "../paths.ts";

type Viewer = Pick<SponsorViewer, "sponsorships" | "email" | "staff">;

export function dashboardPath(slug: string): string {
  return generatePath(paths.sponsorDashboard, { slug });
}

export function applicationPath(slug: string): string {
  return generatePath(paths.sponsorApplicationNew, { slug });
}

// Where the landing page sends a signed-in contact: the conference picker.
export function landingRedirect(viewer: Viewer): string | undefined {
  return viewer.sponsorships.length > 0 ? paths.sponsorConferences : undefined;
}

// Where the picker sends a viewer whose choice is already made: the one conference taking
// applications, or, with none taking them, the contact's latest sponsorship.
export function pickerRedirect(
  conferences: readonly Pick<Conference, "slug">[],
  viewer: Viewer,
): string | undefined {
  const [only] = conferences;
  if (only !== undefined && conferences.length === 1) return dashboardPath(only.slug);

  const latest = viewer.sponsorships[0]?.conference;
  if (conferences.length === 0 && latest !== undefined) return dashboardPath(latest.slug);
  return undefined;
}

// Where the dashboard sends a viewer with no sponsorship of the conference. A visitor who is not
// signed in goes to sign in, as a bookmark of the dashboard is the page of a returning sponsor,
// and comes back afterwards. Anyone else goes to the application form, keeping the query, which
// can carry an invitation code.
export function dashboardRedirect(
  viewer: Viewer,
  slug: string,
  search: string,
): string | undefined {
  if (viewer.sponsorships.some((sponsorship) => sponsorship.conference?.slug === slug)) {
    return undefined;
  }
  if (viewer.email === undefined && !viewer.staff) {
    return signInUrl({ pathname: dashboardPath(slug), search });
  }
  return applicationPath(slug) + search;
}
