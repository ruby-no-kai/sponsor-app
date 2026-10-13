import { Outlet } from "react-router";

// The sponsor area. A path missing from paths.ts loads as its HAML page.
export default function SponsorLayout() {
  return (
    <main className="mx-auto max-w-4xl p-6">
      <Outlet />
    </main>
  );
}
