import { Button, InputGroup, Text } from "@cloudflare/kumo";
import { ConnectError } from "@connectrpc/connect";
import { ClockIcon, WarningIcon, XIcon } from "@phosphor-icons/react";
import type { ReactNode } from "react";
import { Disclosure } from "../../lib/Disclosure.tsx";
import { joined } from "../../lib/FormParts.tsx";
import type { FieldOf } from "../../lib/FormParts.tsx";
import type { FieldError } from "../../lib/fieldErrors.ts";
import { nowInput } from "../../lib/forms.ts";
import { RpcErrorDetails } from "../RouteError.tsx";

// A datetime-local input in minutes, in the browser's time zone, with buttons for now and for none. Kumo reads
// the input's own name rather than the group's label, hence the aria-label.
export function DateTimeInput({
  field,
  label,
  description,
}: {
  field: FieldOf<string>;
  label: string;
  description?: ReactNode;
}) {
  const message = joined(field.state.meta.errors);
  // InputGroup takes only the object form, whose match: true shows it whatever the input's validity.
  const error = message === undefined ? undefined : { message, match: true as const };
  return (
    <InputGroup label={label} description={description} error={error}>
      <InputGroup.Input
        type="datetime-local"
        aria-label={label}
        data-field={field.name}
        step={60}
        value={field.state.value.slice(0, 16)}
        onChange={(event) => field.handleChange(event.target.value)}
        onBlur={field.handleBlur}
      />
      <InputGroup.Addon align="end">
        <InputGroup.Button
          aria-label={`Set ${label} to now`}
          className="md:hidden"
          onClick={() => field.handleChange(nowInput())}
        >
          <ClockIcon />
        </InputGroup.Button>
        <InputGroup.Button
          className="hidden md:inline-flex"
          onClick={() => field.handleChange(nowInput())}
        >
          Now
        </InputGroup.Button>
        <InputGroup.Button
          aria-label={`Clear ${label}`}
          className="md:hidden"
          disabled={field.state.value === ""}
          onClick={() => field.handleChange("")}
        >
          <XIcon />
        </InputGroup.Button>
        <InputGroup.Button
          className="hidden md:inline-flex"
          disabled={field.state.value === ""}
          onClick={() => field.handleChange("")}
        >
          Clear
        </InputGroup.Button>
      </InputGroup.Addon>
    </InputGroup>
  );
}

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

export { ErrorList, joined, Section, useFieldReveal } from "../../lib/FormParts.tsx";
export type { FieldOf } from "../../lib/FormParts.tsx";
