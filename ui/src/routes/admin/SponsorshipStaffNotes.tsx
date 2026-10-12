import { LayerCard, Loader } from "@cloudflare/kumo";
import { generatePath, useParams } from "react-router";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { idFromParam } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import { StaffNotes } from "./StaffNotes.tsx";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";

export default function SponsorshipStaffNotes() {
  const { slug = "", id = "" } = useParams();
  const sponsorshipId = idFromParam(id);
  if (sponsorshipId === undefined) return <NotFound />;
  return <Notes key={id} slug={slug} id={id} sponsorshipId={sponsorshipId} />;
}

function Notes({ slug, id, sponsorshipId }: { slug: string; id: string; sponsorshipId: bigint }) {
  const target = { conferenceSlug: slug, sponsorshipId };
  const notes = useRpc(AdminService.method.listSponsorshipStaffNotes, target);
  const name = useRpc(AdminService.method.getSponsorship, target).data?.sponsorship?.name;
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, "Staff notes", name ?? id);

  if (notes.error !== undefined && notes.data === undefined) throw notes.error;
  if (notes.data === undefined) return <Loader size="lg" />;

  return (
    <div className="flex max-w-3xl flex-col gap-4">
      <PageHeader
        crumbs={[
          { label: conferenceName, href: generatePath(paths.conference, { slug }) },
          { label: name ?? id, href: generatePath(paths.sponsorship, { slug, id }) },
        ]}
        title="Staff notes"
      />
      <LayerCard>
        <LayerCard.Primary>
          <StaffNotes target={target} notes={notes.data.staffNotes} />
        </LayerCard.Primary>
      </LayerCard>
    </div>
  );
}
