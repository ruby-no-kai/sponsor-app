import { LayerCard, Link, Loader, Text } from "@cloudflare/kumo";
import { useEffect } from "react";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { useT } from "../../lib/i18n.tsx";
import { useGoTo } from "../../lib/navigation.ts";
import { useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { dashboardPath, pickerRedirect } from "./shellRedirects.ts";

export default function ConferencePicker() {
  const t = useT();
  const goTo = useGoTo();
  const viewer = useRpc(SponsorService.method.getViewer, {});
  const { data, error } = useRpc(SponsorService.method.listOpenConferences, {});
  useDocumentTitle(t("conferences.index.title"));

  const redirect =
    data !== undefined && viewer.data?.viewer !== undefined
      ? pickerRedirect(data.conferences, viewer.data.viewer)
      : undefined;
  useEffect(() => {
    if (redirect !== undefined) goTo(redirect, { replace: true });
  }, [redirect, goTo]);

  if (viewer.error !== undefined && viewer.data === undefined) throw viewer.error;
  if (error !== undefined && data === undefined) throw error;
  if (data === undefined || viewer.data === undefined || redirect !== undefined) {
    return <Loader size="lg" />;
  }

  return (
    <div className="flex flex-col gap-4">
      <Text variant="heading" size="lg" as="h1">
        {t("conferences.index.title")}
      </Text>
      {data.conferences.length === 0 ? (
        <Text variant="secondary">{t("root.index.no_open_applications")}</Text>
      ) : (
        <ul className="grid gap-4 md:grid-cols-2">
          {data.conferences.map((conference) => (
            <li key={conference.slug}>
              <LayerCard>
                <LayerCard.Primary>
                  <Link href={dashboardPath(conference.slug)}>{conference.name}</Link>
                </LayerCard.Primary>
              </LayerCard>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
