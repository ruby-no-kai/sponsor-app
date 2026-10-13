import { LinkButton, Loader, Text } from "@cloudflare/kumo";
import { useEffect } from "react";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { useT } from "../../lib/i18n.tsx";
import { useGoTo } from "../../lib/navigation.ts";
import { useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { applicationPath, landingRedirect } from "./shellRedirects.ts";

const SIGN_IN_PATH = "/session/new";

export default function Landing() {
  const t = useT();
  const goTo = useGoTo();
  const viewer = useRpc(SponsorService.method.getViewer, {});
  const { data, error } = useRpc(SponsorService.method.listOpenConferences, {});
  useDocumentTitle();

  const redirect = viewer.data?.viewer && landingRedirect(viewer.data.viewer);
  useEffect(() => {
    if (redirect !== undefined) goTo(redirect, { replace: true });
  }, [redirect, goTo]);

  if (viewer.error !== undefined && viewer.data === undefined) throw viewer.error;
  if (error !== undefined && data === undefined) throw error;
  if (data === undefined || viewer.data === undefined || redirect !== undefined) {
    return <Loader size="lg" />;
  }

  const { conferences } = data;
  return (
    <div className="flex flex-col gap-10 py-6">
      <Text variant="heading" size="lg" as="h1">
        <span className="block text-center">{t("sponsor_ui.shell.site_name")}</span>
      </Text>

      {conferences.length === 0 ? (
        <div className="flex flex-col items-center gap-4 text-center">
          <Text>{t("root.index.no_open_applications")}</Text>
          <LinkButton href={SIGN_IN_PATH} variant="primary">
            {t("root.index.login")}
          </LinkButton>
        </div>
      ) : (
        <div className="grid gap-10 text-center md:grid-cols-2">
          <section className="flex flex-col items-center gap-3">
            <Text variant="heading" as="h2">
              {t("root.index.become_a_sponsor")}
            </Text>
            {conferences.length > 1 && <Text>{t("root.index.choose_conference")}</Text>}
            <ul className="flex flex-col items-center gap-2">
              {conferences.map((conference) => (
                <li key={conference.slug}>
                  <LinkButton href={applicationPath(conference.slug)} variant="primary">
                    {t("root.index.sponsor_conference", { conference: conference.name })}
                  </LinkButton>
                </li>
              ))}
            </ul>
          </section>
          <section className="flex flex-col items-center gap-3">
            <Text variant="heading" as="h2">
              {t("root.index.already_a_sponsor")}
            </Text>
            <LinkButton href={SIGN_IN_PATH} variant="primary">
              {t("root.index.login")}
            </LinkButton>
          </section>
        </div>
      )}
    </div>
  );
}
