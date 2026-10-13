import type { LinkComponentProps } from "@cloudflare/kumo";
import { forwardRef } from "react";
import { Link } from "react-router";
import { matchSpaPath } from "../routes/paths.ts";

// Kumo renders every link through this. A path the SPA renders navigates in place, and any other
// is a full page load, which the dev server proxies to Rails' HAML pages.
export const AppLink = forwardRef<HTMLAnchorElement, LinkComponentProps>(function AppLink(
  { href, to: _to, ...props },
  ref,
) {
  if (href !== undefined && props.target === undefined && !props.download && matchSpaPath(href)) {
    return <Link ref={ref} to={href} {...props} />;
  }
  return <a ref={ref} href={href} {...props} />;
});
