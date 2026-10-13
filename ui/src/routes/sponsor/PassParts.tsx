import { Badge, LayerCard, Table, Text } from "@cloudflare/kumo";
import type { ReactNode } from "react";
import type {
  PassRetraction,
  PassTicket,
} from "../../gen/rubykaigi/sponsor_app/sponsor_passes_pb.ts";
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

// The registration's email and every ticket the retraction voids.
export function AffectedTickets({ retraction }: { retraction: PassRetraction }) {
  const t = useT();
  return (
    <div className="flex flex-col gap-3">
      {retraction.email !== undefined && (
        <Text>
          <strong>{t("pass_redemptions.index.table.registration_email")}</strong>{" "}
          <span className="break-all">{retraction.email}</span>
        </Text>
      )}
      <Text variant="heading" as="h2">
        {t("pass_retractions.new.affected_tickets")}
      </Text>
      <div className="overflow-x-auto">
        <Table>
          <Table.Header>
            <Table.Row>
              <Table.Head>{t("pass_redemptions.index.table.ticket_reference")}</Table.Head>
              <Table.Head>{t("pass_redemptions.index.table.release")}</Table.Head>
              <Table.Head>{t("pass_redemptions.index.table.ticket_email")}</Table.Head>
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {retraction.tickets.map((ticket) => (
              <Table.Row key={ticket.reference}>
                <Table.Cell>{ticket.reference}</Table.Cell>
                <Table.Cell>
                  <ReleaseBadge releaseSlug={ticket.releaseSlug} />
                </Table.Cell>
                <Table.Cell className="break-all">{ticket.email}</Table.Cell>
              </Table.Row>
            ))}
          </Table.Body>
        </Table>
      </div>
    </div>
  );
}
