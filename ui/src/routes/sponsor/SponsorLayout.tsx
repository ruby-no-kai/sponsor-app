import { Badge, Button, DropdownMenu, Link, LinkButton, Loader } from "@cloudflare/kumo";
import { CaretDownIcon, ListIcon, TranslateIcon } from "@phosphor-icons/react";
import { useEffect, useMemo } from "react";
import { Outlet, useLocation, useSearchParams } from "react-router";
import { SWRConfig, useSWRConfig } from "swr";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import type { SponsorViewer_Sponsorship } from "../../gen/rubykaigi/sponsor_app/sponsor_viewer_pb.ts";
import { I18nProvider, useT } from "../../lib/i18n.tsx";
import type { I18n } from "../../lib/i18n.tsx";
import { useGoTo } from "../../lib/navigation.ts";
import {
  callRpc,
  revalidationErrorReporter,
  signInUrl,
  useRpc,
  useRpcMutation,
} from "../../lib/rpc.ts";
import { AppNameContext } from "../../lib/title.ts";
import { notifyError } from "../../lib/toast.ts";
import { paths } from "../paths.ts";
import { dashboardPath } from "./shellRedirects.ts";
import { notifyFailure } from "./SponsorRouteError.tsx";

// The locales SetLocale takes, each named in its own language by the translations.
const LOCALES = ["en", "ja"] as const;

type Locale = (typeof LOCALES)[number];

function isLocale(value: string): value is Locale {
  return (LOCALES as readonly string[]).includes(value);
}

// The sponsor area. A path missing from paths.ts loads as its HAML page.
export default function SponsorLayout() {
  const hl = useLocaleParam();
  // Waits for a locale the URL asks for, so the first texts are already in it.
  const { data, error } = useRpc(SponsorService.method.getTranslations, hl === null ? {} : null);
  const i18n = useMemo<I18n | undefined>(
    () =>
      data && {
        locale: data.locale,
        translations: data.translations,
        orgName: data.orgName,
      },
    [data],
  );

  useEffect(() => {
    if (i18n === undefined) return;
    const root = document.documentElement;
    const previous = root.lang;
    root.lang = i18n.locale;
    return () => {
      root.lang = previous;
    };
  }, [i18n]);

  if (error !== undefined && i18n === undefined) throw error;
  if (i18n === undefined) {
    return (
      <div className="flex min-h-svh items-center justify-center">
        <Loader size="lg" />
      </div>
    );
  }

  return (
    <I18nProvider value={i18n}>
      <Shell />
    </I18nProvider>
  );
}

// Applies a `?hl=` the page was loaded with, as the dev server never shows it to Rails, then drops
// it from the URL. Returns the parameter while it is being applied.
function useLocaleParam(): string | null {
  const [searchParams, setSearchParams] = useSearchParams();
  const { mutate } = useSWRConfig();
  const hl = searchParams.get("hl");

  useEffect(() => {
    if (hl === null) return;
    let cancelled = false;
    void (async () => {
      if (isLocale(hl)) {
        try {
          await callRpc(SponsorService.method.setLocale, { locale: hl });
          await mutate(() => true);
        } catch (error) {
          // No texts have loaded to word it in, and the page goes on in the locale chosen before.
          notifyError(error);
        }
      }
      if (cancelled) return;
      setSearchParams(
        (current) => {
          const next = new URLSearchParams(current);
          next.delete("hl");
          return next;
        },
        { replace: true },
      );
    })();
    return () => {
      cancelled = true;
    };
  }, [hl, mutate, setSearchParams]);

  return hl;
}

function Shell() {
  const t = useT();
  const swrConfig = useMemo(
    () => ({ onError: revalidationErrorReporter((error) => notifyFailure(t, error)) }),
    [t],
  );

  return (
    <AppNameContext.Provider value={t("sponsor_ui.shell.site_name")}>
      <SWRConfig value={swrConfig}>
        <div className="flex min-h-svh flex-col">
          <NavBar />
          <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-6 md:px-6">
            <Outlet />
          </main>
        </div>
      </SWRConfig>
    </AppNameContext.Provider>
  );
}

type NavActions = {
  // The contact's sponsorships, or undefined when no sponsor contact is signed in.
  sponsorships: SponsorViewer_Sponsorship[] | undefined;
  staff: boolean;
  changeLocale(locale: Locale): void;
  signIn(): void;
};

function useNavActions(): NavActions {
  const t = useT();
  const location = useLocation();
  const { mutate } = useSWRConfig();
  const viewer = useRpc(SponsorService.method.getViewer, {}).data?.viewer;
  const setLocale = useRpcMutation(SponsorService.method.setLocale);

  return {
    sponsorships: viewer?.email === undefined ? undefined : viewer.sponsorships,
    staff: viewer?.staff ?? false,
    changeLocale(locale) {
      void (async () => {
        try {
          await setLocale.trigger({ locale });
        } catch (error) {
          notifyFailure(t, error);
          return;
        }
        await mutate(() => true);
      })();
    },
    signIn() {
      window.location.assign(signInUrl(location));
    },
  };
}

// The bar on a wide screen, folded into one menu on a narrow one.
function NavBar() {
  const t = useT();
  const actions = useNavActions();
  const { sponsorships, staff } = actions;

  return (
    <header className="border-b border-kumo-line bg-kumo-base">
      <nav className="mx-auto flex max-w-5xl items-center gap-4 px-4 py-3 md:px-6">
        <LinkButton href={paths.sponsorLanding} variant="ghost" className="font-semibold">
          {t("layouts.application.brand")}
        </LinkButton>

        <div className="hidden flex-1 items-center gap-4 md:flex">
          <LinkButton href={paths.sponsorConferences} variant="ghost">
            {t("layouts.application.conferences")}
          </LinkButton>
          {sponsorships !== undefined && sponsorships.length > 0 && (
            <DropdownMenu>
              <DropdownMenu.Trigger>
                <Button variant="ghost">
                  {t("layouts.application.sponsorships_switch")} <CaretDownIcon />
                </Button>
              </DropdownMenu.Trigger>
              <DropdownMenu.Content>
                <SponsorshipItems sponsorships={sponsorships} />
              </DropdownMenu.Content>
            </DropdownMenu>
          )}
          <div className="flex-1" />
          <DropdownMenu>
            <DropdownMenu.Trigger>
              <Button variant="ghost" icon={TranslateIcon}>
                {t("sponsor_ui.shell.language")}
              </Button>
            </DropdownMenu.Trigger>
            <DropdownMenu.Content>
              <LocaleItems changeLocale={actions.changeLocale} />
            </DropdownMenu.Content>
          </DropdownMenu>
          {staff && (
            <Link href={paths.admin} variant="plain">
              <Badge variant="error">{t("sponsor_ui.shell.staff_mode")}</Badge>
            </Link>
          )}
          {sponsorships === undefined && (
            <Button variant="ghost" onClick={actions.signIn}>
              {t("layouts.application.login")}
            </Button>
          )}
        </div>

        <div className="flex flex-1 justify-end md:hidden">
          <CompactMenu {...actions} />
        </div>
      </nav>
    </header>
  );
}

function CompactMenu({ sponsorships, staff, changeLocale, signIn }: NavActions) {
  const t = useT();
  const goTo = useGoTo();

  return (
    <DropdownMenu>
      <DropdownMenu.Trigger>
        <Button
          variant="ghost"
          shape="square"
          icon={ListIcon}
          aria-label={t("sponsor_ui.shell.menu")}
        />
      </DropdownMenu.Trigger>
      <DropdownMenu.Content>
        <DropdownMenu.Item onClick={() => goTo(paths.sponsorConferences)}>
          {t("layouts.application.conferences")}
        </DropdownMenu.Item>
        {sponsorships !== undefined && sponsorships.length > 0 && (
          <DropdownMenu.Group>
            <DropdownMenu.Label>{t("layouts.application.sponsorships_switch")}</DropdownMenu.Label>
            <SponsorshipItems sponsorships={sponsorships} />
          </DropdownMenu.Group>
        )}
        <DropdownMenu.Separator />
        <DropdownMenu.Group>
          <DropdownMenu.Label>{t("sponsor_ui.shell.language")}</DropdownMenu.Label>
          <LocaleItems changeLocale={changeLocale} />
        </DropdownMenu.Group>
        <DropdownMenu.Separator />
        {staff && (
          <DropdownMenu.Item onClick={() => goTo(paths.admin)}>
            {t("sponsor_ui.shell.staff_mode")}
          </DropdownMenu.Item>
        )}
        {sponsorships === undefined && (
          <DropdownMenu.Item onClick={signIn}>{t("layouts.application.login")}</DropdownMenu.Item>
        )}
      </DropdownMenu.Content>
    </DropdownMenu>
  );
}

function SponsorshipItems({ sponsorships }: { sponsorships: SponsorViewer_Sponsorship[] }) {
  const goTo = useGoTo();
  return sponsorships.map(({ id, conference }) =>
    conference === undefined ? null : (
      <DropdownMenu.Item key={id.toString()} onClick={() => goTo(dashboardPath(conference.slug))}>
        {conference.name}
      </DropdownMenu.Item>
    ),
  );
}

function LocaleItems({ changeLocale }: { changeLocale(locale: Locale): void }) {
  const t = useT();
  return LOCALES.map((locale) => (
    <DropdownMenu.Item
      key={locale}
      selected={locale === t.locale}
      className="gap-3"
      onClick={() => changeLocale(locale)}
    >
      {t(`sponsor_ui.shell.language_names.${locale}`)}
    </DropdownMenu.Item>
  ));
}
