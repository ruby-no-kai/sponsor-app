import { Link, LinkButton, Loader, Table, Text } from "@cloudflare/kumo";
import type { ReactNode } from "react";
import { useParams } from "react-router";
import type {
  PassDiscountCode,
  PassRegistration,
} from "../../gen/rubykaigi/sponsor_app/sponsor_passes_pb.ts";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { useT } from "../../lib/i18n.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { Card, ReleaseBadge, StateBadge } from "./PassParts.tsx";
import { invitationKey, newRetractionPath } from "./passesView.ts";

// The registrations made with the sponsorship's discount codes, as the ticketing service has them.
export default function PassRedemptions() {
  const { slug = "" } = useParams();
  const t = useT();
  // Each answer asks the ticketing service, so only a page load or a revisit asks again.
  const { data, error } = useRpc(
    SponsorService.method.listPassRedemptions,
    { conferenceSlug: slug },
    { revalidateOnFocus: false },
  );
  useDocumentTitle(t("pass_redemptions.index.title"), data?.conference?.name);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const { conference } = data;
  if (conference === undefined) throw new Error("ListPassRedemptions returned no conference");

  const voidHref = (registration: PassRegistration) =>
    data.retractionEnabled && registration.retractable
      ? newRetractionPath(slug, registration.id)
      : undefined;

  return (
    <div className="flex flex-col gap-4">
      <Text variant="heading" size="lg" as="h1">
        {t("pass_redemptions.index.header")} - {conference.name}
      </Text>

      <Card title={t("pass_redemptions.index.invitation.title")}>
        {data.discountCodes.map((code) => (
          <DiscountCode key={code.kind} code={code} />
        ))}
        <ul className="list-disc pl-5">
          <li>
            <Text size="sm">{t("sponsorships.show.tickets.help.requirement")}</Text>
          </li>
          <li>
            <Text size="sm">{t("sponsorships.show.tickets.help.unique")}</Text>
          </li>
        </ul>
      </Card>

      <Card title={t("pass_redemptions.index.card_title")}>
        {data.registrations.length === 0 ? (
          <Text variant="secondary">{t("pass_redemptions.index.no_registrations")}</Text>
        ) : (
          <>
            <div className="hidden md:block">
              <RegistrationTable registrations={data.registrations} voidHref={voidHref} />
            </div>
            <div className="md:hidden">
              <RegistrationList registrations={data.registrations} voidHref={voidHref} />
            </div>
          </>
        )}
        <ul className="flex list-disc flex-col gap-2 border-t border-kumo-line pt-3 pl-5">
          <Note>{t("pass_redemptions.index.notes.overview")}</Note>
          <Note>{t("pass_redemptions.index.notes.registration_vs_ticket")}</Note>
          <Note>
            {t("pass_redemptions.index.notes.email_management", {
              conference_name: conference.name,
            })}
          </Note>
          <Note>{t("pass_redemptions.index.notes.reassignment")}</Note>
          <Note>{t("pass_redemptions.index.notes.incomplete_status")}</Note>
          <li>
            <Text size="sm">
              <span
                className="[&_a]:break-all [&_a]:text-kumo-link [&_a]:underline"
                dangerouslySetInnerHTML={{
                  __html: t.html(
                    data.retractionEnabled
                      ? "pass_redemptions.index.notes.retraction_enabled_html"
                      : "pass_redemptions.index.notes.retraction_disabled_html",
                    { contact_email: conference.contactEmailAddress },
                  ),
                }}
              />
            </Text>
          </li>
        </ul>
      </Card>
    </div>
  );
}

function Note({ children }: { children: ReactNode }) {
  return (
    <li>
      <Text size="sm">{children}</Text>
    </li>
  );
}

function DiscountCode({ code }: { code: PassDiscountCode }) {
  const t = useT();
  return (
    <div className="flex flex-col gap-1">
      <Text>
        <strong>{t(invitationKey(code.kind))}</strong>
        {code.quantity !== undefined && (
          <Text variant="secondary" as="span">
            {" "}
            ({t("pass_redemptions.index.invitation.quantity", { count: code.quantity })})
          </Text>
        )}
      </Text>
      <Link href={code.url} target="_blank" rel="noreferrer" className="break-all">
        {code.url}
      </Link>
    </div>
  );
}

type RegistrationsProps = {
  registrations: PassRegistration[];
  // Where the registration's Void button leads, or undefined when it shows none.
  voidHref: (registration: PassRegistration) => string | undefined;
};

function VoidButton({ href }: { href: string }) {
  const t = useT();
  return (
    <LinkButton href={href} variant="destructive" size="sm">
      {t("pass_redemptions.index.table.retract")}
    </LinkButton>
  );
}

// One row per ticket, the registration's own cells spanning its tickets, and the registrations
// shaded in turn.
function RegistrationTable({ registrations, voidHref }: RegistrationsProps) {
  const t = useT();
  return (
    <Table>
      <Table.Header>
        <Table.Row>
          <Table.Head />
          <Table.Head>{t("pass_redemptions.index.table.registration_reference")}</Table.Head>
          <Table.Head>{t("pass_redemptions.index.table.ticket_reference")}</Table.Head>
          <Table.Head>{t("pass_redemptions.index.table.release")}</Table.Head>
          <Table.Head>{t("pass_redemptions.index.table.registration_email")}</Table.Head>
          <Table.Head>{t("pass_redemptions.index.table.ticket_email")}</Table.Head>
          <Table.Head>{t("pass_redemptions.index.table.ticket_state")}</Table.Head>
        </Table.Row>
      </Table.Header>
      <Table.Body>
        {registrations.flatMap((registration, registrationIndex) => {
          const href = voidHref(registration);
          const span = registration.tickets.length;
          const shade =
            registrationIndex % 2 === 1
              ? "bg-kumo-elevated even:bg-kumo-elevated"
              : "bg-kumo-base even:bg-kumo-base";
          return registration.tickets.map((ticket, ticketIndex) => (
            <Table.Row
              key={`${registration.id}-${ticket.reference}`}
              className={ticketIndex === 0 && registrationIndex > 0 ? `${shade} border-t-2` : shade}
            >
              {ticketIndex === 0 && (
                <>
                  <Table.Cell rowSpan={span} className="text-center align-middle">
                    {href !== undefined && <VoidButton href={href} />}
                  </Table.Cell>
                  <Table.Cell rowSpan={span} className="align-middle">
                    {registration.reference}
                  </Table.Cell>
                </>
              )}
              <Table.Cell>{ticket.reference}</Table.Cell>
              <Table.Cell>
                <ReleaseBadge releaseSlug={ticket.releaseSlug} />
              </Table.Cell>
              {ticketIndex === 0 && (
                <Table.Cell rowSpan={span} className="align-middle break-all">
                  {registration.email}
                </Table.Cell>
              )}
              <Table.Cell className="break-all">{ticket.email}</Table.Cell>
              <Table.Cell>
                <StateBadge ticket={ticket} />
              </Table.Cell>
            </Table.Row>
          ));
        })}
      </Table.Body>
    </Table>
  );
}

// The table's contents for a phone: a block per registration, a line per ticket.
function RegistrationList({ registrations, voidHref }: RegistrationsProps) {
  const t = useT();
  return (
    <ul className="flex flex-col divide-y divide-kumo-line">
      {registrations
        .filter((registration) => registration.tickets.length > 0)
        .map((registration) => {
          const href = voidHref(registration);
          return (
            <li key={registration.id} className="flex flex-col gap-2 py-3 first:pt-0">
              <dl className="grid grid-cols-[max-content_1fr] items-center gap-x-3 gap-y-1">
                <Field label={t("pass_redemptions.index.table.registration_reference")}>
                  {registration.reference}
                </Field>
                <Field label={t("pass_redemptions.index.table.registration_email")}>
                  {registration.email}
                </Field>
              </dl>
              <ul className="flex flex-col gap-2 border-l-2 border-kumo-line pl-3">
                {registration.tickets.map((ticket) => (
                  <li key={ticket.reference}>
                    <dl className="grid grid-cols-[max-content_1fr] items-center gap-x-3 gap-y-1">
                      <Field label={t("pass_redemptions.index.table.ticket_reference")}>
                        {ticket.reference}
                      </Field>
                      <Field label={t("pass_redemptions.index.table.release")}>
                        <ReleaseBadge releaseSlug={ticket.releaseSlug} />
                      </Field>
                      <Field label={t("pass_redemptions.index.table.ticket_email")}>
                        {ticket.email}
                      </Field>
                      <Field label={t("pass_redemptions.index.table.ticket_state")}>
                        <StateBadge ticket={ticket} />
                      </Field>
                    </dl>
                  </li>
                ))}
              </ul>
              {href !== undefined && (
                <div>
                  <VoidButton href={href} />
                </div>
              )}
            </li>
          );
        })}
    </ul>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <>
      <Text as="dt" variant="secondary" size="sm">
        {label}
      </Text>
      <dd className="min-w-0 break-all">{children}</dd>
    </>
  );
}
