import { create, fromJsonString, toJsonString } from "@bufbuild/protobuf";
import type {
  DescMessage,
  DescMethod,
  DescMethodUnary,
  MessageInitShape,
  MessageShape,
} from "@bufbuild/protobuf";
import { Code, ConnectError } from "@connectrpc/connect";
import type { Interceptor } from "@connectrpc/connect";
import { createConnectTransport } from "@connectrpc/connect-web";
import useSWR from "swr";
import type { SWRConfiguration, SWRResponse } from "swr";
import useSWRMutation from "swr/mutation";
import type { SWRMutationResponse } from "swr/mutation";
import { notifyError } from "./toast.ts";

// The sign-in page that brings the browser back to location afterwards.
export function signInUrl(location: { pathname: string; search: string }): string {
  const { pathname, search } = location;
  const signIn =
    pathname === "/admin" || pathname.startsWith("/admin/") ? "/admin/session/new" : "/session/new";
  return `${signIn}?back_to=${encodeURIComponent(pathname + search)}`;
}

// The session cookie belongs to the Rails sign-in flow, so an expired one sends the whole page there.
const signInOnUnauthenticated: Interceptor = (next) => async (req) => {
  try {
    return await next(req);
  } catch (error) {
    if (error instanceof ConnectError && error.code === Code.Unauthenticated) {
      window.location.assign(signInUrl(window.location));
    }
    throw error;
  }
};

// Whether an RPC failed for want of a session, which signInOnUnauthenticated is already taking the
// browser to the sign-in page for.
export function isSigningIn(error: unknown): boolean {
  return error instanceof ConnectError && error.code === Code.Unauthenticated;
}

// Same-origin, so the session cookie goes along. The API's forgery protection relies on the
// Connect-Protocol-Version header and Sec-Fetch-Site rather than a CSRF token.
export const transport = createConnectTransport({
  baseUrl: "/",
  useHttpGet: true,
  interceptors: [signInOnUnauthenticated],
});

export async function callRpc<I extends DescMessage, O extends DescMessage>(
  method: DescMethodUnary<I, O>,
  input: MessageInitShape<I>,
): Promise<MessageShape<O>> {
  const response = await transport.unary(method, undefined, undefined, undefined, input);
  return response.message;
}

export type RpcKey = readonly [service: string, method: string, input: string];

// Strings only: SWR hashes a message's bytes fields and descriptors by identity.
export function rpcKey<I extends DescMessage, O extends DescMessage>(
  method: DescMethodUnary<I, O>,
  input: MessageInitShape<I>,
): RpcKey {
  return [
    method.parent.typeName,
    method.name,
    toJsonString(method.input, create(method.input, input)),
  ];
}

// Whether an SWR key is one useRpc caches the method's answers under, for mutate's filter form.
export function isRpcKeyOf(key: unknown, method: DescMethod): boolean {
  return Array.isArray(key) && key[0] === method.parent.typeName && key[1] === method.name;
}

// Calls an RPC through SWR. A null input skips the call.
export function useRpc<I extends DescMessage, O extends DescMessage>(
  method: DescMethodUnary<I, O>,
  input: MessageInitShape<I> | null,
  config?: SWRConfiguration<MessageShape<O>, ConnectError>,
): SWRResponse<MessageShape<O>, ConnectError> {
  return useSWR<MessageShape<O>, ConnectError, RpcKey | null>(
    input === null ? null : rpcKey(method, input),
    ([, , json]) => callRpc(method, fromJsonString(method.input, json)),
    config,
  );
}

export function useRpcMutation<I extends DescMessage, O extends DescMessage>(
  method: DescMethodUnary<I, O>,
): SWRMutationResponse<
  MessageShape<O>,
  ConnectError,
  readonly [string, string],
  MessageInitShape<I>
> {
  return useSWRMutation<
    MessageShape<O>,
    ConnectError,
    readonly [string, string],
    MessageInitShape<I>
  >([method.parent.typeName, method.name], (_key, { arg }) => callRpc(method, arg));
}

// Retrying cannot change these answers.
const FINAL_CODES: ReadonlySet<Code> = new Set([
  Code.Unauthenticated,
  Code.PermissionDenied,
  Code.NotFound,
  Code.InvalidArgument,
  Code.FailedPrecondition,
  Code.AlreadyExists,
  Code.Aborted,
]);

export function isRetryable(error: unknown): boolean {
  return !(error instanceof ConnectError && FINAL_CODES.has(error.code));
}

// Keys that have loaded once. SWR keeps their data on screen when a later revalidation fails, so
// only those failures need a toast: a page with nothing to show renders the error itself.
const loadedKeys = new Set<string>();

// An SWR onError that reports a failed revalidation through notify. A tree in another language
// passes its own in a nested SWRConfig.
export function revalidationErrorReporter(
  notify: (error: unknown) => void,
): (error: unknown, key: string) => void {
  return (error, key) => {
    if (isSigningIn(error)) return;
    if (loadedKeys.has(key)) notify(error);
  };
}

export const swrConfig: SWRConfiguration = {
  shouldRetryOnError: isRetryable,
  onSuccess(_data: unknown, key: string) {
    loadedKeys.add(key);
  },
  onError: revalidationErrorReporter(notifyError),
};
