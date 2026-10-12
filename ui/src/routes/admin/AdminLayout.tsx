import { Badge, Button, Loader, Sidebar, Text, useSidebar } from "@cloudflare/kumo";
import {
  BuildingsIcon,
  CalendarBlankIcon,
  CalendarDotsIcon,
  CoinsIcon,
  EnvelopeSimpleIcon,
  ListChecksIcon,
  MegaphoneIcon,
  PencilSimpleIcon,
  PresentationIcon,
  ReceiptIcon,
  SignOutIcon,
  SquaresFourIcon,
  StorefrontIcon,
  TableIcon,
} from "@phosphor-icons/react";
import type { Icon } from "@phosphor-icons/react";
import { useEffect } from "react";
import { Outlet, generatePath, useLocation, useParams } from "react-router";
import { unload } from "swr";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { isSigningIn, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { notifyError } from "../../lib/toast.ts";
import { paths } from "../paths.ts";

export default function AdminLayout() {
  const { slug } = useParams();

  return (
    <Sidebar.Provider defaultOpen>
      {/* The column runs the page's full height, with its content sticky in the viewport. */}
      <Sidebar
        className="md:box-content md:border-r md:border-kumo-line"
        contentClassName="md:sticky md:top-0 md:h-svh border-r-0"
      >
        <Sidebar.Header>
          <Text variant="heading" as="h1">
            Sponsor App
          </Text>
        </Sidebar.Header>
        <Sidebar.Content>
          {slug !== undefined && <ConferenceSections slug={slug} />}
          <ConferencesGroup currentSlug={slug} />
        </Sidebar.Content>
        <Sidebar.Footer>
          <ViewerPanel />
        </Sidebar.Footer>
      </Sidebar>
      <main className="min-w-0 flex-1 p-6">
        <MobileHeader />
        <Outlet />
      </main>
    </Sidebar.Provider>
  );
}

// Below Kumo's mobile breakpoint the sidebar is a sheet off the screen, which this opens. Moving to
// another page closes it.
function MobileHeader() {
  const { openMobile, setOpenMobile } = useSidebar();
  const { pathname } = useLocation();
  useEffect(() => setOpenMobile(false), [pathname, setOpenMobile]);

  return (
    <div className="-mt-2 mb-4 flex items-center gap-2 md:hidden">
      <Sidebar.Trigger aria-label="Open navigation" aria-expanded={openMobile} />
      <Text variant="heading" as="span">
        Sponsor App
      </Text>
    </div>
  );
}

type Section = { label: string; icon: Icon; path: string };

// AppLink decides per path whether a section opens in the SPA or as its HAML page.
function conferenceSections(slug: string): Section[] {
  const base = `/admin/conferences/${encodeURIComponent(slug)}`;
  return [
    { label: "Overview", icon: PresentationIcon, path: generatePath(paths.conference, { slug }) },
    { label: "Plans", icon: CoinsIcon, path: `${base}/plans` },
    { label: "Booth assignment", icon: StorefrontIcon, path: `${base}/booth_assignment` },
    { label: "Events", icon: CalendarDotsIcon, path: `${base}/events` },
    { label: "Announcements", icon: MegaphoneIcon, path: `${base}/announcements` },
    { label: "Broadcasts", icon: EnvelopeSimpleIcon, path: `${base}/broadcasts` },
    { label: "Expense reports", icon: ReceiptIcon, path: `${base}/expense_reports` },
    { label: "Check attendees", icon: ListChecksIcon, path: `${base}/attendees_keeper` },
    { label: "Table view", icon: TableIcon, path: `${base}/table_view` },
    { label: "Edit conference", icon: PencilSimpleIcon, path: `${base}/edit` },
  ];
}

// Listed only for a conference the viewer can manage, so a mistyped slug shows no menu.
function ConferenceSections({ slug }: { slug: string }) {
  const { pathname } = useLocation();
  const { data } = useRpc(AdminService.method.listConferences, {});
  const conference = data?.conferences.find((entry) => entry.conference?.slug === slug)?.conference;
  if (conference === undefined) return null;

  return (
    <Sidebar.Group>
      <Sidebar.GroupLabel>{conference.name}</Sidebar.GroupLabel>
      <Sidebar.Menu>
        {conferenceSections(slug).map(({ label, icon, path }) => (
          <Sidebar.MenuButton
            key={path}
            icon={icon}
            href={path}
            active={pathname === path}
            tooltip={label}
          >
            {label}
          </Sidebar.MenuButton>
        ))}
      </Sidebar.Menu>
    </Sidebar.Group>
  );
}

function ConferencesGroup({ currentSlug }: { currentSlug: string | undefined }) {
  const { pathname } = useLocation();
  const { data, error } = useRpc(AdminService.method.listConferences, {});
  const viewer = useRpc(AdminService.method.getViewer, {}).data?.staff;

  return (
    <Sidebar.Group>
      <Sidebar.GroupLabel>Conferences</Sidebar.GroupLabel>
      <Sidebar.Menu>
        <Sidebar.MenuButton
          icon={SquaresFourIcon}
          href={paths.conferences}
          active={pathname === paths.conferences}
          tooltip="All conferences"
        >
          All conferences
        </Sidebar.MenuButton>
        {data?.conferences.map(({ conference, hidden }) => {
          if (conference === undefined) return null;
          return (
            <Sidebar.MenuButton
              key={conference.slug}
              icon={CalendarBlankIcon}
              href={generatePath(paths.conference, { slug: conference.slug })}
              active={conference.slug === currentSlug}
            >
              {conference.name}
              {hidden && <Sidebar.MenuBadge>Hidden</Sidebar.MenuBadge>}
            </Sidebar.MenuButton>
          );
        })}
        {viewer !== undefined && !viewer.restricted && (
          <Sidebar.MenuButton
            icon={BuildingsIcon}
            href="/admin/organizations"
            tooltip="Organizations"
          >
            Organizations
          </Sidebar.MenuButton>
        )}
      </Sidebar.Menu>
      {error !== undefined && data === undefined && !isSigningIn(error) && (
        <Text variant="error" size="sm">
          Conferences failed to load.
        </Text>
      )}
    </Sidebar.Group>
  );
}

function ViewerPanel() {
  const { data, error } = useRpc(AdminService.method.getViewer, {});
  const signOut = useRpcMutation(AdminService.method.signOut);

  async function handleSignOut() {
    try {
      await signOut.trigger({});
    } catch (signOutError) {
      notifyError(signOutError);
      return;
    }
    unload({ revalidate: false });
    window.location.assign("/admin/session/new");
  }

  const staff = data?.staff;
  if (staff === undefined) {
    return error === undefined || isSigningIn(error) ? (
      <Loader size="sm" />
    ) : (
      <Text variant="error" size="sm">
        Not signed in.
      </Text>
    );
  }

  // The footer is one row high, so the restricted badge sits beside the name.
  return (
    <div className="flex min-w-0 flex-1 items-center gap-2">
      {staff.avatarUrl !== undefined && (
        <img
          src={staff.avatarUrl}
          alt=""
          className="size-7 shrink-0 rounded-full"
          referrerPolicy="no-referrer"
        />
      )}
      <div className="min-w-0 flex-1 leading-tight">
        <div className="flex min-w-0 items-center gap-1">
          <Text bold size="sm" truncate>
            {staff.name}
          </Text>
          {staff.restricted && <Badge variant="warning">Restricted</Badge>}
        </div>
        <Text variant="secondary" size="xs" truncate>
          @{staff.login}
        </Text>
      </div>
      <Button
        variant="ghost"
        shape="square"
        icon={SignOutIcon}
        aria-label="Sign out"
        loading={signOut.isMutating}
        onClick={() => void handleSignOut()}
      />
    </div>
  );
}
