import { generatePath, matchPath } from "react-router";
import { paths } from "../paths.ts";

// Where switching to another conference lands: the same section of it, or its overview from a
// page without one, such as a sponsorship.
export function switchedConferencePath(
  pathname: string,
  sectionPatterns: readonly string[],
  slug: string,
): string {
  const section = sectionPatterns
    .filter((pattern) => pattern !== paths.conference)
    .find((pattern) => matchPath({ path: pattern, end: false }, pathname) !== null);
  return generatePath(section ?? paths.conference, { slug });
}
