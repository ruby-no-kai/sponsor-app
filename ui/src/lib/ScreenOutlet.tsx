import { Loader } from "@cloudflare/kumo";
import { Suspense } from "react";
import { Outlet, useNavigation } from "react-router";
import { SWRConfig } from "swr";

// Screens suspend until their first fetch answers. A navigation is a transition, so the current
// screen stays until the next one has its data, and only a first visit shows the loader.
export function ScreenOutlet() {
  return (
    <SWRConfig value={{ suspense: true }}>
      <Suspense fallback={<Loader size="lg" />}>
        <Outlet />
      </Suspense>
    </SWRConfig>
  );
}

// A bar along the top of the viewport while a navigation waits for its screen.
export function NavigationProgress() {
  const navigation = useNavigation();
  if (navigation.state === "idle") return null;

  return (
    <div
      role="progressbar"
      aria-label="Loading page"
      className="pointer-events-none fixed inset-x-0 top-0 z-50 h-0.5 overflow-hidden opacity-0 animate-[navigation-progress-appear_0s_150ms_forwards]"
    >
      <div className="h-full w-1/3 bg-kumo-brand animate-[navigation-progress_1s_ease-in-out_infinite] motion-reduce:w-full motion-reduce:animate-none" />
    </div>
  );
}
