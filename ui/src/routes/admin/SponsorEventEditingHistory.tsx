import { Loader } from "@cloudflare/kumo";
import { generatePath, useParams } from "react-router";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { idFromParam } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import { EditingHistoryEntries } from "./EditingHistoryEntries.tsx";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";

export default function SponsorEventEditingHistory() {
  const { slug = "", id = "" } = useParams();
  const sponsorEventId = idFromParam(id);
  if (sponsorEventId === undefined) return <NotFound />;
  return <History key={id} slug={slug} id={id} sponsorEventId={sponsorEventId} />;
}

function History({
  slug,
  id,
  sponsorEventId,
}: {
  slug: string;
  id: string;
  sponsorEventId: bigint;
}) {
  const target = { conferenceSlug: slug, sponsorEventId };
  const history = useRpc(AdminService.method.listSponsorEventEditingHistory, target);
  const title = useRpc(AdminService.method.getSponsorEvent, target).data?.sponsorEvent?.title;
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, "Editing history", title ?? id);

  if (history.error !== undefined && history.data === undefined) throw history.error;
  if (history.data === undefined) return <Loader size="lg" />;

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[
          { label: conferenceName, href: generatePath(paths.conference, { slug }) },
          { label: "Events", href: generatePath(paths.sponsorEvents, { slug }) },
          { label: title ?? id, href: generatePath(paths.sponsorEvent, { slug, id }) },
        ]}
        title="Editing history"
      />

      <EditingHistoryEntries
        entries={history.data.entries}
        emptyDescription="The event has no recorded saves."
      />
    </div>
  );
}
