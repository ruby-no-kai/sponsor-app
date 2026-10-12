import { Button, Text } from "@cloudflare/kumo";
import { ConnectError } from "@connectrpc/connect";
import { WarningIcon } from "@phosphor-icons/react";
import { useEffect, useRef, useState } from "react";
import type { ReactNode, RefObject } from "react";
import { Disclosure } from "../../lib/Disclosure.tsx";
import { parentPath } from "../../lib/fieldErrors.ts";
import type { FieldError } from "../../lib/fieldErrors.ts";
import { RpcErrorDetails } from "../RouteError.tsx";

function fixFieldsText(count: number): string {
  return count === 1 ? "Fix 1 field to save." : `Fix ${count} fields to save.`;
}

// In a SaveBar, so a rejected save is seen whichever field it concerns. It leads with what to do,
// names the first field, and keeps the error's codes behind "Details". Renders nothing while the
// form has no error.
export function SaveErrorBanner({
  formError,
  errored,
  error,
  onShow,
}: {
  formError: unknown;
  errored: readonly FieldError[];
  error: unknown;
  onShow: (path: string) => void;
}) {
  const [first] = errored;
  if (typeof formError !== "string" && first === undefined) return null;
  const lead =
    first !== undefined
      ? fixFieldsText(errored.length)
      : typeof formError === "string"
        ? formError
        : "Not saved.";
  return (
    <div role="alert" className="flex flex-col gap-1 text-sm">
      <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
        <WarningIcon className="shrink-0 text-kumo-danger" />
        <Text bold variant="error">
          {lead}
        </Text>
        {first !== undefined && <Text>{`${first.label} ${first.message}`}</Text>}
        {first !== undefined && (
          <Button variant="secondary" size="sm" onClick={() => onShow(first.path)}>
            Show
          </Button>
        )}
      </div>
      {first !== undefined && typeof formError === "string" && <Text>{formError}</Text>}
      {error !== undefined && (
        <Disclosure label="Details">
          <RpcErrorDetails error={ConnectError.from(error)} withCode />
        </Disclosure>
      )}
    </div>
  );
}

// The save area of a long editor, pinned to the bottom of the viewport: the save buttons, a note
// while the form has unsaved edits, and the error summary of a rejected save.
export function SaveBar({
  isDirty,
  banner,
  children,
}: {
  isDirty: boolean;
  banner?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="sticky bottom-0 z-10 -mx-6 flex max-h-[50svh] flex-col gap-2 overflow-y-auto border-t border-kumo-line bg-kumo-base px-6 py-3">
      {banner}
      <div className="flex flex-wrap items-center gap-3">
        {children}
        {isDirty && (
          <Text variant="secondary" size="sm">
            Unsaved changes
          </Text>
        )}
      </div>
    </div>
  );
}

// Scrolls the form to the field a path names, found by its data-field attribute, once the form
// has rendered the errors that may add it.
export function useFieldReveal(): {
  formRef: RefObject<HTMLFormElement | null>;
  reveal: (path: string) => void;
} {
  const formRef = useRef<HTMLFormElement>(null);
  // A fresh object per call, so the same field is scrolled to again.
  const [target, setTarget] = useState<{ path: string }>();

  useEffect(() => {
    if (target !== undefined) revealField(formRef.current, target.path);
  }, [target]);

  return { formRef, reveal: (path) => setTarget({ path }) };
}

// Scrolls to the field at a path, or else the nearest one enclosing it, and focuses a text field.
function revealField(form: HTMLFormElement | null, path: string): void {
  for (let at: string | undefined = path; at !== undefined; at = parentPath(at)) {
    const element = form?.querySelector<HTMLElement>(`[data-field="${CSS.escape(at)}"]`);
    if (element === null || element === undefined) continue;
    element.scrollIntoView({ behavior: "smooth", block: "center" });
    if (element.matches("input, textarea")) element.focus({ preventScroll: true });
    return;
  }
}
