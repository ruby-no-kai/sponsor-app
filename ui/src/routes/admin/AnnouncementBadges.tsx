import { Badge } from "@cloudflare/kumo";

export function AnnouncementBadges({
  pinned,
  exhibitorsOnly,
  published,
  behind = false,
}: {
  pinned: boolean;
  exhibitorsOnly: boolean;
  published: boolean;
  behind?: boolean;
}) {
  return (
    <>
      {pinned && <Badge variant="info">Pin</Badge>}
      {exhibitorsOnly && <Badge variant="primary">Exhibitors only</Badge>}
      {!published && <Badge variant="warning">Draft</Badge>}
      {behind && <Badge variant="error">Behind</Badge>}
    </>
  );
}
