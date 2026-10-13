import { generatePath } from "react-router";
import { paths } from "../paths.ts";

export function exhibitionNewPath(slug: string): string {
  return generatePath(paths.sponsorExhibitionNew, { slug });
}

export function exhibitionEditPath(slug: string): string {
  return generatePath(paths.sponsorExhibitionEdit, { slug });
}
