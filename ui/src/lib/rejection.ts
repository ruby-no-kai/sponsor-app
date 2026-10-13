import type { AnyFormApi } from "@tanstack/react-form";
import { useState } from "react";
import type { FormErrors } from "./errors.ts";

// A save the server or the form refused: the values sent, and the errors they drew.
export type Rejected = { values: unknown; errors: FormErrors };

// The value at a TanStack field path, such as `fallbackOptions[1].value`. A path below a value the
// form holds whole, such as `emails[1]` of addresses typed one per line, reaches that value.
export function valueAt(values: unknown, path: string): unknown {
  let value = values;
  for (const [, name, index] of path.matchAll(/([^.[\]]+)|\[(\d+)\]/g)) {
    if (value === null || value === undefined) return undefined;
    if (typeof value !== "object") return value;
    value = (value as Record<string, unknown>)[name ?? index ?? ""];
  }
  return value;
}

function isSameValue(a: unknown, b: unknown): boolean {
  if (Object.is(a, b)) return true;
  if (Array.isArray(a) || Array.isArray(b)) {
    return (
      Array.isArray(a) &&
      Array.isArray(b) &&
      a.length === b.length &&
      a.every((item, at) => isSameValue(item, b[at]))
    );
  }
  if (a === null || b === null || typeof a !== "object" || typeof b !== "object") return false;
  const x = a as Record<string, unknown>;
  const y = b as Record<string, unknown>;
  const keys = Object.keys(x);
  return (
    keys.length === Object.keys(y).length &&
    keys.every((key) => Object.hasOwn(y, key) && isSameValue(x[key], y[key]))
  );
}

// The errors of a refused save that still apply: a field's while it holds the value refused, and
// the form-level message until the next save.
export function standingErrors(
  rejected: Rejected | undefined,
  values: unknown,
): FormErrors | undefined {
  if (rejected === undefined) return undefined;
  const { form, fields } = rejected.errors;
  const standing = Object.fromEntries(
    Object.entries(fields).filter(([path]) =>
      isSameValue(valueAt(values, path), valueAt(rejected.values, path)),
    ),
  );
  if (form === undefined && Object.keys(standing).length === 0) return undefined;
  return form === undefined ? { fields: standing } : { form, fields: standing };
}

// Keeps the errors of a refused save on a TanStack form as its onChange validator's, so a blur
// leaves them and changing a field clears that field's. The form validates nothing else: a form
// the server refused may always be sent again, so sending drops the last save's errors first.
export class SaveRejection {
  #rejected: Rejected | undefined = undefined;

  // For the form's validators.onChange. Its errors are the form's errorMap.onChange.
  readonly validate = ({ value }: { value: unknown }): FormErrors | undefined =>
    standingErrors(this.#rejected, value);

  // Puts the errors on the form, against the values the refused save was sent with.
  reject(form: AnyFormApi, sent: unknown, errors: FormErrors): void {
    this.#rejected = { values: structuredClone(sent), errors };
    form.validate("change");
  }

  submit(form: AnyFormApi): Promise<void> {
    if (this.#rejected !== undefined) {
      this.#rejected = undefined;
      form.validate("change");
    }
    return form.handleSubmit();
  }
}

export function useSaveRejection(): SaveRejection {
  const [rejection] = useState(() => new SaveRejection());
  return rejection;
}
