import { Empty, LayerCard, Link, LinkButton, Loader, Text } from "@cloudflare/kumo";
import { MegaphoneIcon, PlusIcon } from "@phosphor-icons/react";
import { generatePath, useParams } from "react-router";
import type { AdminAnnouncementIssue } from "../../gen/rubykaigi/sponsor_app/admin_announcements_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { paths } from "../paths.ts";
import { AnnouncementBadges } from "./AnnouncementBadges.tsx";
import { announcementNewPath, announcementPath } from "./announcementForm.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";

export default function AnnouncementList() {
  const { slug = "" } = useParams();
  const { data, error } = useRpc(AdminService.method.listAnnouncements, { conferenceSlug: slug });
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, "Announcements");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;

  const newAnnouncement = announcementNewPath(slug);

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[{ label: conferenceName, href: generatePath(paths.conference, { slug }) }]}
        title="Announcements"
        actions={
          <LinkButton href={newAnnouncement} variant="primary" icon={PlusIcon}>
            New announcement
          </LinkButton>
        }
      />

      {data.issues.length === 0 ? (
        <Empty
          icon={<MegaphoneIcon size={32} />}
          title="No announcements"
          description="Sponsors read announcements on their sponsorship page."
          contents={
            <LinkButton href={newAnnouncement} variant="secondary" icon={PlusIcon}>
              Write the first announcement
            </LinkButton>
          }
        />
      ) : (
        data.issues.map((issue) => <IssueCard key={issue.issue} slug={slug} issue={issue} />)
      )}
    </div>
  );
}

// One row per locale the issue is written in.
function IssueCard({ slug, issue }: { slug: string; issue: AdminAnnouncementIssue }) {
  return (
    <LayerCard className="p-0">
      <ul className="divide-y divide-kumo-hairline">
        {issue.announcements.map((announcement) => (
          <li key={announcement.locale} className="flex items-baseline gap-4 px-4 py-2">
            <Text variant="mono" as="span">
              {announcement.locale}
            </Text>
            <span className="inline-flex min-w-0 flex-wrap items-center gap-1">
              <Link href={announcementPath(slug, issue.issue, announcement.locale)}>
                {announcement.title}
              </Link>
              <AnnouncementBadges
                pinned={announcement.pinned}
                exhibitorsOnly={announcement.exhibitorsOnly}
                published={announcement.published}
                behind={announcement.behind}
              />
            </span>
          </li>
        ))}
      </ul>
    </LayerCard>
  );
}
