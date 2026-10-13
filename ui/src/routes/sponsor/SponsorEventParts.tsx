import { Banner, LinkButton } from "@cloudflare/kumo";
import { WarningIcon } from "@phosphor-icons/react";
import { useT } from "../../lib/i18n.tsx";
import { dashboardPath } from "./shellRedirects.ts";

// Says why an event page offers nothing to do, with the way back.
export function SponsorEventBack({
  slug,
  message,
  back,
}: {
  slug: string;
  message: string;
  // Where back leads, and what it is called. The sponsorship portal by default.
  back?: { href: string; label: string };
}) {
  const t = useT();
  return (
    <div className="flex flex-col items-start gap-4">
      <Banner variant="alert" icon={<WarningIcon />} description={message} />
      <LinkButton href={back?.href ?? dashboardPath(slug)} variant="secondary">
        {back?.label ?? t("sponsor_ui.events.back_to_portal")}
      </LinkButton>
    </div>
  );
}
