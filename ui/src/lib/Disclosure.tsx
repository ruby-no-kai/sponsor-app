import { Collapsible } from "@cloudflare/kumo";
import type { ReactNode } from "react";

// A "Details"-style toggle that keeps its content out of the way until asked for.
export function Disclosure({
  label,
  children,
  defaultOpen = false,
}: {
  label: ReactNode;
  children: ReactNode;
  defaultOpen?: boolean;
}) {
  return (
    <Collapsible defaultOpen={defaultOpen}>
      <Collapsible.DefaultTrigger className="text-sm text-kumo-subtle">
        {label}
      </Collapsible.DefaultTrigger>
      <Collapsible.DefaultPanel>{children}</Collapsible.DefaultPanel>
    </Collapsible>
  );
}
