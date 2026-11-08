import { Badge, Button, DropdownMenu, Loader, Sidebar, Text, useSidebar } from "@cloudflare/kumo";
import {
  BuildingsIcon,
  CalendarBlankIcon,
  CalendarDotsIcon,
  CaretUpDownIcon,
  CheckIcon,
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
import { generatePath, useLocation, useParams } from "react-router";
import { unload } from "swr";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { AppLink } from "../../lib/AppLink.tsx";
import { ScreenOutlet } from "../../lib/ScreenOutlet.tsx";
import { isSigningIn, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { notifyError } from "../../lib/toast.ts";
import { paths } from "../paths.ts";
import { switchedConferencePath } from "./conferenceSwitch.ts";

export default function AdminLayout() {
  const { slug } = useParams();

  return (
    <Sidebar.Provider defaultOpen>
      {/* The column runs the page's full height, with its content sticky in the viewport. Kumo's
          h-full would stop the column at the viewport's height. */}
      <Sidebar
        className="md:box-content md:h-auto md:self-stretch md:border-r md:border-kumo-line"
        contentClassName="md:sticky md:top-0 md:h-svh border-r-0"
      >
        <Sidebar.Header>
          <ConferenceSwitcher currentSlug={slug} />
        </Sidebar.Header>
        <Sidebar.Content>
          {slug !== undefined && <ConferenceSections slug={slug} />}
          <GlobalSections />
        </Sidebar.Content>
        <Sidebar.Footer>
          <ViewerPanel />
        </Sidebar.Footer>
      </Sidebar>
      <main className="min-w-0 flex-1 p-6">
        <MobileHeader />
        <ScreenOutlet />
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

type Section = { label: string; icon: Icon; pattern: string };

// AppLink decides per path whether a section opens in the SPA or as its HAML page.
function conferenceSections({ isEditable }: { isEditable: boolean }): Section[] {
  return [
    { label: "Overview", icon: PresentationIcon, pattern: paths.conference },
    { label: "Plans", icon: CoinsIcon, pattern: paths.plans },
    { label: "Booth assignment", icon: StorefrontIcon, pattern: paths.boothAssignment },
    { label: "Events", icon: CalendarDotsIcon, pattern: paths.sponsorEvents },
    { label: "Announcements", icon: MegaphoneIcon, pattern: paths.announcements },
    { label: "Broadcasts", icon: EnvelopeSimpleIcon, pattern: paths.broadcasts },
    { label: "Expense reports", icon: ReceiptIcon, pattern: paths.expenseReports },
    { label: "Attendees", icon: ListChecksIcon, pattern: paths.attendeesKeeper },
    { label: "Table view", icon: TableIcon, pattern: paths.sponsorshipTable },
    ...(isEditable
      ? [{ label: "Edit conference", icon: PencilSimpleIcon, pattern: paths.conferenceEdit }]
      : []),
  ];
}

function useIsUnrestricted(): boolean {
  const viewer = useRpc(AdminService.method.getViewer, {}).data?.staff;
  return viewer !== undefined && !viewer.restricted;
}

// Picks the conference the sections below work on, as a cloud console picks its account.
function ConferenceSwitcher({ currentSlug }: { currentSlug: string | undefined }) {
  const { pathname } = useLocation();
  const isEditable = useIsUnrestricted();
  const { data, error } = useRpc(AdminService.method.listConferences, {});
  const current = data?.conferences.find((entry) => entry.conference?.slug === currentSlug);
  const patterns = conferenceSections({ isEditable }).map((section) => section.pattern);

  return (
    <DropdownMenu>
      <DropdownMenu.Trigger
        render={
          <button
            type="button"
            className="flex w-full min-w-0 cursor-pointer items-center gap-2 rounded-lg px-3 py-2 text-left text-sm font-medium text-kumo-default outline-none ring ring-kumo-line hover:bg-kumo-tint focus-visible:ring-kumo-focus"
          >
            <CalendarBlankIcon className="size-4 shrink-0 text-kumo-brand" weight="duotone" />
            <span className="flex min-w-0 flex-1 items-center gap-1.5 overflow-hidden">
              {current?.conference !== undefined ? (
                <>
                  <span className="truncate">{current.conference.name}</span>
                  {current.hidden && <Badge variant="secondary">Hidden</Badge>}
                </>
              ) : (
                <span className="truncate text-kumo-subtle">Choose a conference</span>
              )}
            </span>
            <span className="w-4 shrink-0 overflow-hidden group-data-[state=collapsed]/sidebar:w-0">
              <CaretUpDownIcon className="size-4 text-kumo-subtle" />
            </span>
          </button>
        }
      />
      <DropdownMenu.Content className="w-(--anchor-width) min-w-56">
        <DropdownMenu.Group>
          <DropdownMenu.Label>Conferences</DropdownMenu.Label>
          {data?.conferences.map(({ conference, hidden }) =>
            conference === undefined ? null : (
              <DropdownMenu.LinkItem
                key={conference.slug}
                render={
                  <AppLink href={switchedConferencePath(pathname, patterns, conference.slug)} />
                }
                className="gap-1.5"
              >
                <span className="truncate">{conference.name}</span>
                {hidden && <Badge variant="secondary">Hidden</Badge>}
                {conference.slug === currentSlug && (
                  <CheckIcon className="ml-auto size-4 shrink-0" aria-label="Current" />
                )}
              </DropdownMenu.LinkItem>
            ),
          )}
          {error !== undefined && data === undefined && !isSigningIn(error) && (
            <DropdownMenu.Item disabled>Conferences failed to load.</DropdownMenu.Item>
          )}
        </DropdownMenu.Group>
        <DropdownMenu.Separator />
        <DropdownMenu.LinkItem icon={SquaresFourIcon} render={<AppLink href={paths.conferences} />}>
          All conferences
        </DropdownMenu.LinkItem>
      </DropdownMenu.Content>
    </DropdownMenu>
  );
}

// Listed only for a conference the viewer can manage, so a mistyped slug shows no menu.
function ConferenceSections({ slug }: { slug: string }) {
  const { pathname } = useLocation();
  const { data } = useRpc(AdminService.method.listConferences, {});
  const isEditable = useIsUnrestricted();
  const conference = data?.conferences.find((entry) => entry.conference?.slug === slug)?.conference;
  if (conference === undefined) return null;

  return (
    <Sidebar.Group>
      <Sidebar.Menu>
        {conferenceSections({ isEditable }).map(({ label, icon, pattern }) => {
          const path = generatePath(pattern, { slug });
          return (
            <Sidebar.MenuButton
              key={pattern}
              icon={icon}
              href={path}
              active={pathname === path}
              tooltip={label}
            >
              {label}
            </Sidebar.MenuButton>
          );
        })}
      </Sidebar.Menu>
    </Sidebar.Group>
  );
}

// Pages that span every conference, as a cloud console's global services do.
function GlobalSections() {
  const { pathname } = useLocation();
  if (!useIsUnrestricted()) return null;

  return (
    <Sidebar.Group>
      <Sidebar.GroupLabel>Across conferences</Sidebar.GroupLabel>
      <Sidebar.Menu>
        <Sidebar.MenuButton
          icon={BuildingsIcon}
          href={paths.organizations}
          active={pathname === paths.organizations}
          tooltip="Organizations"
        >
          Organizations
        </Sidebar.MenuButton>
      </Sidebar.Menu>
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
