import { Banner, Empty, Loader, Text } from "@cloudflare/kumo";
import { ConnectError } from "@connectrpc/connect";
import { MapTrifoldIcon, WarningIcon } from "@phosphor-icons/react";
import { isRouteErrorResponse, useRouteError } from "react-router";
import { Disclosure } from "../lib/Disclosure.tsx";
import {
  codeName,
  isNotFoundError,
  isRetryable,
  problemDetailsOf,
  problemTypeName,
  problemTypeOf,
  requestIdOf,
} from "../lib/errors.ts";
import { isSigningIn } from "../lib/rpc.ts";
import { useDocumentTitle } from "../lib/title.ts";

export function NotFound() {
  useDocumentTitle("Page not found");
  return (
    <Empty
      icon={<MapTrifoldIcon size={32} />}
      title="Page not found"
      description="Nothing in this app lives at this address."
    />
  );
}

export type ErrorTexts = {
  // The headline of an error that carries no problem title.
  fallbackTitle: string;
  // Advice for an error that trying again may fix.
  retry: string;
  details: string;
  requestId: (requestId: string) => string;
};

const STAFF_TEXTS: ErrorTexts = {
  fallbackTitle: "Something went wrong",
  retry: "Try again later. If this keeps happening, contact the maintainers with the request ID.",
  details: "Details",
  requestId: (requestId) => `Request ID: ${requestId}`,
};

// What a failed RPC reports: the problem's title and detail as the server worded them, advice to
// retry only where retrying can help, and the request ID to quote behind "Details". With
// `developer`, the Connect code and message show too, for the staff area.
export function ProblemBanner({
  error,
  texts = STAFF_TEXTS,
  developer = false,
}: {
  error: unknown;
  texts?: ErrorTexts;
  developer?: boolean;
}) {
  const connectError = ConnectError.from(error);
  const problem = problemDetailsOf(error);
  const requestId = requestIdOf(error);
  const detail = problem?.detail || (developer ? connectError.rawMessage : "");
  const hasDetails = developer || requestId !== undefined;

  return (
    <Banner
      variant="error"
      icon={<WarningIcon />}
      title={problem?.title || texts.fallbackTitle}
      description={
        <div className="flex flex-col gap-2">
          {detail !== "" && <Text>{detail}</Text>}
          {isRetryable(error) && <Text>{texts.retry}</Text>}
          {hasDetails && (
            <Disclosure label={texts.details}>
              {developer ? (
                <RpcErrorDetails error={connectError} withCode />
              ) : (
                requestId !== undefined && <Text variant="mono">{texts.requestId(requestId)}</Text>
              )}
            </Disclosure>
          )}
        </div>
      }
    />
  );
}

// The problem type and request ID of a failed RPC, and its Connect code when a title lacks it.
export function RpcErrorDetails({
  error,
  withCode = false,
}: {
  error: ConnectError;
  withCode?: boolean;
}) {
  const problemType = problemTypeOf(error);
  const requestId = requestIdOf(error);
  return (
    <dl className="grid grid-cols-[max-content_1fr] gap-x-3">
      {withCode && (
        <>
          <dt>Code</dt>
          <dd>
            <Text variant="mono">{codeName(error)}</Text>
          </dd>
        </>
      )}
      {problemType !== undefined && (
        <>
          <dt>Problem type</dt>
          <dd>
            <Text variant="mono">{problemTypeName(problemType)}</Text>
          </dd>
        </>
      )}
      {requestId !== undefined && (
        <>
          <dt>Request ID</dt>
          <dd>
            <Text variant="mono">{requestId}</Text>
          </dd>
        </>
      )}
    </dl>
  );
}

// Unpadded, as it renders in the place of a page inside the layout's padding.
export function RouteError() {
  const error = useRouteError();
  const notFound = (isRouteErrorResponse(error) && error.status === 404) || isNotFoundError(error);
  const signingIn = isSigningIn(error);
  useDocumentTitle(notFound ? "Page not found" : signingIn ? undefined : "Error");

  if (notFound) return <NotFound />;
  if (signingIn) return <Loader size="lg" />;
  return <ProblemBanner error={error} developer />;
}

// For an error no layout catches.
export function RootError() {
  return (
    <main className="p-6">
      <RouteError />
    </main>
  );
}
