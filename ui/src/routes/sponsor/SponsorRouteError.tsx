import { Banner, Empty, LinkButton, Loader } from "@cloudflare/kumo";
import { Code, ConnectError } from "@connectrpc/connect";
import { MapTrifoldIcon, WarningIcon } from "@phosphor-icons/react";
import { isRouteErrorResponse, useParams, useRouteError } from "react-router";
import {
  isNotFoundError,
  isRetryable,
  preconditionDetail,
  problemDetailsOf,
  requestIdOf,
} from "../../lib/errors.ts";
import { useT } from "../../lib/i18n.tsx";
import type { Translate } from "../../lib/i18n.tsx";
import { useDocumentTitle } from "../../lib/title.ts";
import { toastManager } from "../../lib/toast.ts";
import { ProblemBanner } from "../RouteError.tsx";
import { dashboardPath } from "./shellRedirects.ts";
import type { ErrorTexts } from "../RouteError.tsx";

export function SponsorNotFound() {
  const t = useT();
  useDocumentTitle(t("sponsor_ui.shell.not_found.title"));
  return (
    <Empty
      icon={<MapTrifoldIcon size={32} />}
      title={t("sponsor_ui.shell.not_found.title")}
      description={t("sponsor_ui.shell.not_found.description")}
    />
  );
}

// A sponsor reads the problem's title and detail, which the server words in their language, and
// finds the request ID to quote to the organizers behind "Details". The Connect code and message
// are for developers.
export function SponsorRouteError() {
  const t = useT();
  const error = useRouteError();
  const notFound = (isRouteErrorResponse(error) && error.status === 404) || isNotFoundError(error);
  // The RPC transport is already taking the browser to the sign-in page.
  const signingIn = error instanceof ConnectError && error.code === Code.Unauthenticated;
  useDocumentTitle(signingIn || notFound ? undefined : t("sponsor_ui.shell.error.title"));

  if (notFound) return <SponsorNotFound />;
  if (signingIn) return <Loader size="lg" />;
  const unmet = preconditionDetail(error);
  if (unmet !== undefined) return <PreconditionNotice message={unmet} />;
  return <ProblemBanner error={error} texts={errorTexts(t)} />;
}

// A page that cannot be offered, such as the passes of a conference without ticketing, explains
// why in the server's words and leads back to the portal.
function PreconditionNotice({ message }: { message: string }) {
  const t = useT();
  const { slug = "" } = useParams();
  return (
    <div className="flex flex-col items-start gap-4">
      <Banner variant="alert" icon={<WarningIcon />} description={message} />
      <LinkButton href={dashboardPath(slug)} variant="secondary">
        {t("sponsor_ui.shell.back_to_portal")}
      </LinkButton>
    </div>
  );
}

function errorTexts(t: Translate): ErrorTexts {
  return {
    fallbackTitle: t("sponsor_ui.shell.error.title"),
    retry: t("sponsor_ui.shell.error.description"),
    details: t("sponsor_ui.shell.error.details"),
    requestId: (requestId) => t("sponsor_ui.shell.error.request_id", { request_id: requestId }),
  };
}

// Reports a failed action, such as signing out, in the sponsor's language.
export function notifyFailure(t: Translate, error: unknown): void {
  const requestId = requestIdOf(error);
  const description = [
    problemDetailsOf(error)?.detail,
    isRetryable(error) ? t("sponsor_ui.shell.error.description") : undefined,
    requestId === undefined
      ? undefined
      : t("sponsor_ui.shell.error.request_id", { request_id: requestId }),
  ]
    .filter((part) => part !== undefined && part !== "")
    .join(" ");
  toastManager.add({
    variant: "error",
    title: problemDetailsOf(error)?.title || t("sponsor_ui.shell.error.title"),
    description: description === "" ? undefined : description,
  });
}
