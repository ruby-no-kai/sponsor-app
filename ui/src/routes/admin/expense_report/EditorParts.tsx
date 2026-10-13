import { Text } from "@cloudflare/kumo";
import type { ReactNode } from "react";

export function PaneHeader({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-2 border-b border-kumo-line bg-kumo-recessed px-3 py-2">
      <Text bold size="sm">
        {title}
      </Text>
      {children}
    </div>
  );
}
