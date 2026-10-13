import { generatePath } from "react-router";
import { idFromParam } from "../../lib/forms.ts";
import { paths } from "../paths.ts";

export function eventNewPath(slug: string): string {
  return generatePath(paths.sponsorOwnEventNew, { slug });
}

export function eventPath(slug: string, id: bigint | string): string {
  return generatePath(paths.sponsorOwnEvent, { slug, id: String(id) });
}

export function eventEditPath(slug: string, id: bigint | string): string {
  return generatePath(paths.sponsorOwnEventEdit, { slug, id: String(id) });
}

export function exhibitionNewPath(slug: string): string {
  return generatePath(paths.sponsorExhibitionNew, { slug });
}

export function exhibitionEditPath(slug: string): string {
  return generatePath(paths.sponsorExhibitionEdit, { slug });
}

// The event a route parameter names, or undefined when it names none and the page is not found.
export function eventIdFromParam(param: string | undefined): bigint | undefined {
  if (param === undefined) return undefined;
  const id = idFromParam(param);
  return id === undefined || id === 0n || id > 2n ** 63n - 1n ? undefined : id;
}
