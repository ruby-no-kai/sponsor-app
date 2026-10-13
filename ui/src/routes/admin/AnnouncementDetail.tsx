import { LayerCard, LinkButton, Loader, Tabs, Text, useLinkComponent } from "@cloudflare/kumo";
import { ArrowSquareOutIcon, PencilSimpleIcon } from "@phosphor-icons/react";
import { generatePath, useParams } from "react-router";
import type { AdminAnnouncementSummary } from "../../gen/rubykaigi/sponsor_app/admin_announcements_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { formatTimestamp } from "../../lib/forms.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import { AnnouncementBadges } from "./AnnouncementBadges.tsx";
import {
  announcementEditPath,
  announcementNewPath,
  announcementPath,
  defaultLocale,
  parseAnnouncementId,
} from "./announcementForm.ts";
import { SandboxedHtml } from "../../lib/SandboxedHtml.tsx";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";

const NEW_LOCALE_TAB = "+";

export default function AnnouncementDetail() {
  const { slug = "", id = "" } = useParams();
  const key = parseAnnouncementId(id);
  if (key === undefined) return <NotFound />;
  return <Detail key={id} slug={slug} id={id} target={key} />;
}

function Detail({
  slug,
  id,
  target,
}: {
  slug: string;
  id: string;
  target: { issue: string; locale: string };
}) {
  const { data, error } = useRpc(AdminService.method.getAnnouncement, {
    conferenceSlug: slug,
    ...target,
  });
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, data?.announcement?.title ?? id, "Announcements");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;

  const { announcement } = data;
  if (announcement === undefined) throw new Error("GetAnnouncement returned no announcement");
  const locales = data.issue?.announcements ?? [];
  const current = locales.find((locale) => locale.locale === announcement.locale);

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[
          { label: conferenceName, href: generatePath(paths.conference, { slug }) },
          { label: "Announcements", href: generatePath(paths.announcements, { slug }) },
        ]}
        title="Announcement"
        subtitle={<Text variant="mono">{announcement.issue}</Text>}
      />

      <LocaleTabs
        slug={slug}
        issue={announcement.issue}
        current={announcement.locale}
        locales={locales}
      />

      <LayerCard>
        <LayerCard.Secondary className="flex flex-wrap items-center justify-between gap-2">
          <span className="inline-flex min-w-0 flex-wrap items-center gap-1">
            <Text bold>{announcement.title}</Text>
            <AnnouncementBadges
              pinned={announcement.pinned}
              exhibitorsOnly={announcement.exhibitorsOnly}
              published={announcement.published}
              behind={current?.behind}
            />
          </span>
          <span className="flex gap-2">
            <LinkButton
              href={announcement.sponsorPageUrl}
              variant="secondary"
              size="sm"
              icon={ArrowSquareOutIcon}
              external
            >
              Sponsor page
            </LinkButton>
            <LinkButton
              href={announcementEditPath(slug, announcement.issue, announcement.locale)}
              variant="primary"
              size="sm"
              icon={PencilSimpleIcon}
            >
              Edit
            </LinkButton>
          </span>
        </LayerCard.Secondary>
        <LayerCard.Primary className="flex flex-col gap-3">
          <Text variant="secondary" size="sm">
            Revision {announcement.revision}.{" "}
            {announcement.published
              ? `Published ${formatTimestamp(announcement.publishedAt)}.`
              : "A draft, which sponsors cannot read yet."}
          </Text>
          <SandboxedHtml html={announcement.bodyHtml} title={announcement.title} />
        </LayerCard.Primary>
      </LayerCard>
    </div>
  );
}

// A tab per locale the issue is written in, and one writing it in another while one is left.
function LocaleTabs({
  slug,
  issue,
  current,
  locales,
}: {
  slug: string;
  issue: string;
  current: string;
  locales: readonly AdminAnnouncementSummary[];
}) {
  const LinkComponent = useLinkComponent();
  const unwritten = defaultLocale(locales.map(({ locale }) => locale)) !== "";
  return (
    <Tabs
      variant="underline"
      value={current}
      tabs={[
        ...locales.map(({ locale, behind }) => ({
          value: locale,
          label: behind ? `${locale} (behind)` : locale,
          nativeButton: false,
          render: <LinkComponent href={announcementPath(slug, issue, locale)} />,
        })),
        ...(unwritten
          ? [
              {
                value: NEW_LOCALE_TAB,
                label: NEW_LOCALE_TAB,
                nativeButton: false,
                render: (
                  <LinkComponent
                    href={announcementNewPath(slug, issue)}
                    aria-label="Write in another locale"
                  />
                ),
              },
            ]
          : []),
      ]}
    />
  );
}
