import type { ReactNode } from "react";

// A table from md up and, below it, one stacked item per row, so a wide table never scrolls
// sideways on a phone. `stack` holds <StackedRow>s.
export function TableOrStack({ table, stack }: { table: ReactNode; stack: ReactNode }) {
  return (
    <>
      <div className="hidden md:block">{table}</div>
      <ul className="divide-y divide-kumo-line md:hidden">{stack}</ul>
    </>
  );
}

export function StackedRow({ children }: { children: ReactNode }) {
  return <li className="flex flex-col gap-1 px-4 py-3">{children}</li>;
}
