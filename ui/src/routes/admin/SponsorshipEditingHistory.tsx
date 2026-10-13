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

export default function SponsorshipEditingHistory() {
  const { slug = "", id = "" } = useParams();
  const sponsorshipId = idFromParam(id);
  if (sponsorshipId === undefined) return <NotFound />;
  return <History key={id} slug={slug} id={id} sponsorshipId={sponsorshipId} />;
}

function History({ slug, id, sponsorshipId }: { slug: string; id: string; sponsorshipId: bigint }) {
  const target = { conferenceSlug: slug, sponsorshipId };
  const history = useRpc(AdminService.method.listSponsorshipEditingHistory, target);
  const name = useRpc(AdminService.method.getSponsorship, target).data?.sponsorship?.name;
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, "Editing history", name ?? id);

  if (history.error !== undefined && history.data === undefined) throw history.error;
  if (history.data === undefined) return <Loader size="lg" />;

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[
          { label: conferenceName, href: generatePath(paths.conference, { slug }) },
          { label: name ?? id, href: generatePath(paths.sponsorship, { slug, id }) },
        ]}
        title="Editing history"
      />

      <EditingHistoryEntries
        entries={history.data.entries}
        emptyDescription="The sponsorship has no recorded saves."
      />
    </div>
  );
}
