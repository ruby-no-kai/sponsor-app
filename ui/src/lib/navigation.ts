import { useCallback } from "react";
import { useNavigate } from "react-router";
import { matchSpaPath } from "../routes/paths.ts";

export type GoToOptions = { replace?: boolean };

// What goTo moves with: the router for an SPA path, the browser for any other.
export type Navigator = {
  navigate(to: string, options: { replace: boolean }): void;
  assign(url: string): void;
  replace(url: string): void;
};

// Navigates in place to a path the SPA renders, and loads any other as a page of its own. The
// router would render its NotFound for a path it lacks, where the browser gets the HAML page.
export function goTo(
  href: string,
  { replace = false }: GoToOptions,
  navigator: Navigator,
  base: string = window.location.href,
): void {
  if (matchSpaPath(href, base)) {
    const url = new URL(href, base);
    navigator.navigate(url.pathname + url.search + url.hash, { replace });
  } else if (replace) {
    navigator.replace(href);
  } else {
    navigator.assign(href);
  }
}

export function useGoTo(): (href: string, options?: GoToOptions) => void {
  const navigate = useNavigate();
  return useCallback(
    (href: string, options: GoToOptions = {}) =>
      goTo(href, options, {
        navigate: (to, navigateOptions) => void navigate(to, navigateOptions),
        assign: (url) => window.location.assign(url),
        replace: (url) => window.location.replace(url),
      }),
    [navigate],
  );
}
