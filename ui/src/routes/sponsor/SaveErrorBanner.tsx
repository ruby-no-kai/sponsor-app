import { Banner, Button, Text } from "@cloudflare/kumo";
import { WarningIcon } from "@phosphor-icons/react";
import { requestIdOf } from "../../lib/errors.ts";
import type { FieldError } from "../../lib/fieldErrors.ts";
import { useT } from "../../lib/i18n.tsx";

// Beside the submit button, so a refused save is seen whichever field it concerns. The Connect
// code is for developers, so only the request ID shows.
export function SaveErrorBanner({
  title,
  formError,
  errored,
  error,
  labelOf,
  onShow,
}: {
  title: string;
  formError: unknown;
  errored: readonly FieldError[];
  // The error of the last request, for its ID.
  error: unknown;
  labelOf: (path: string) => string;
  onShow: (path: string) => void;
}) {
  const t = useT();
  const [first] = errored;
  if (typeof formError !== "string" && first === undefined) return null;
  const requestId = error === undefined ? undefined : requestIdOf(error);
  return (
    <Banner
      variant="error"
      icon={<WarningIcon />}
      title={title}
      description={
        <div className="flex flex-col gap-2">
          {typeof formError === "string" && <div>{formError}</div>}
          {first !== undefined && (
            <div className="flex flex-wrap items-center gap-2">
              <span>
                {t("sponsor_ui.applications.fields_need_attention", {
                  count: errored.length,
                  field: labelOf(first.path),
                  message: first.message,
                })}
              </span>
              <Button variant="secondary" size="sm" onClick={() => onShow(first.path)}>
                {t("sponsor_ui.applications.show")}
              </Button>
            </div>
          )}
          {requestId !== undefined && (
            <Text variant="mono">
              {t("sponsor_ui.shell.error.request_id", { request_id: requestId })}
            </Text>
          )}
        </div>
      }
    />
  );
}
