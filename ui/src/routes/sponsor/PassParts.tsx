import { Badge, LayerCard } from "@cloudflare/kumo";
import type { ReactNode } from "react";
import type { PassTicket } from "../../gen/rubykaigi/sponsor_app/sponsor_passes_pb.ts";
import { useT } from "../../lib/i18n.tsx";
import { badgeText, releaseLabel, ticketStateLabel } from "./passesView.ts";

export function Card({ title, children }: { title?: string; children: ReactNode }) {
  return (
    <LayerCard>
      {title !== undefined && <LayerCard.Secondary>{title}</LayerCard.Secondary>}
      <LayerCard.Primary className="flex flex-col gap-3">{children}</LayerCard.Primary>
    </LayerCard>
  );
}

export function ReleaseBadge({ releaseSlug }: { releaseSlug: string | undefined }) {
  const t = useT();
  if (releaseSlug === undefined) return null;
  const label = releaseLabel(releaseSlug);
  return <Badge variant={label.variant}>{badgeText(t, label)}</Badge>;
}

export function StateBadge({ ticket }: { ticket: Pick<PassTicket, "state" | "void"> }) {
  const t = useT();
  const label = ticketStateLabel(ticket);
  return <Badge variant={label.variant}>{badgeText(t, label)}</Badge>;
}
