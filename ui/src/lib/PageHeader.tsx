import { Link, Text } from "@cloudflare/kumo";
import type { ReactNode } from "react";

export type Crumb = { label: string; href: string };

// A breadcrumb row above the page's h2, with the page's actions to the right of the title.
export function PageHeader({
  crumbs = [],
  title,
  subtitle,
  actions,
}: {
  crumbs?: readonly Crumb[];
  title: ReactNode;
  subtitle?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <header className="flex flex-col gap-1">
      {crumbs.length > 0 && (
        <nav aria-label="Breadcrumb">
          <ol className="flex flex-wrap items-center gap-x-1.5 text-kumo-subtle">
            {crumbs.map((crumb, index) => (
              <li key={crumb.href} className="flex items-center gap-1.5">
                {index > 0 && <span aria-hidden>›</span>}
                <Link href={crumb.href} variant="plain">
                  {crumb.label}
                </Link>
              </li>
            ))}
          </ol>
        </nav>
      )}
      <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-2">
        <div className="flex min-w-0 flex-col">
          <Text variant="heading" size="lg" as="h2">
            {title}
          </Text>
          {subtitle !== undefined && (
            <Text variant="secondary" as="span">
              {subtitle}
            </Text>
          )}
        </div>
        {actions !== undefined && (
          <div className="flex flex-wrap items-center gap-2">{actions}</div>
        )}
      </div>
    </header>
  );
}
