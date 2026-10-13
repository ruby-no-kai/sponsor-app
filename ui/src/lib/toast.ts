import { createKumoToastManager } from "@cloudflare/kumo";
import { ConnectError } from "@connectrpc/connect";
import { codeName, requestIdOf } from "./errors.ts";

// Passed to <Toasty>, so code outside React, such as SWR's callbacks, can show toasts.
export const toastManager = createKumoToastManager();

export function notifyError(error: unknown): void {
  const connectError = ConnectError.from(error);
  const requestId = requestIdOf(connectError);
  toastManager.add({
    variant: "error",
    title: `${codeName(connectError)}: ${connectError.rawMessage}`,
    description: requestId === undefined ? undefined : `Request ID: ${requestId}`,
  });
}
