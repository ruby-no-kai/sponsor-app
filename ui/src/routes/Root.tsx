import { LinkProvider, Loader } from "@cloudflare/kumo";
import { Outlet } from "react-router";
import { AppLink } from "../lib/AppLink.tsx";

// AppLink renders React Router's Link, which needs the router around it.
export function Root() {
  return (
    <LinkProvider component={AppLink}>
      <Outlet />
    </LinkProvider>
  );
}

// Shown while the first page's lazy route modules load.
export function RootFallback() {
  return (
    <div className="flex min-h-svh items-center justify-center">
      <Loader size="lg" />
    </div>
  );
}
