import { generatePath } from "react-router";
import type { Conference } from "../../gen/rubykaigi/sponsor_app/conference_pb.ts";
import type { SponsorViewer } from "../../gen/rubykaigi/sponsor_app/sponsor_viewer_pb.ts";
import { paths } from "../paths.ts";

type Viewer = Pick<SponsorViewer, "sponsorships">;

// The dashboard, which HAML still renders.
export function dashboardPath(slug: string): string {
  return generatePath("/conferences/:slug/sponsorship", { slug });
}

// The application form, which HAML still renders.
export function applicationPath(slug: string): string {
  return `${dashboardPath(slug)}/new`;
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
