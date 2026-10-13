import { Code, ConnectError } from "@connectrpc/connect";
import { fieldViolations, problemDetailsOf } from "../../lib/errors.ts";
import type { FormErrors } from "../../lib/errors.ts";

// The sentence the server worded in the sponsor's language for a precondition that does not hold,
// such as a sponsorship not accepted yet. Undefined for any other error.
export function preconditionMessage(error: unknown): string | undefined {
  if (ConnectError.from(error).code !== Code.FailedPrecondition) return undefined;
  return problemDetailsOf(error)?.detail || undefined;
}

// Whether the server found no such resource, so that the page is not found.
export function isNotFound(error: unknown): boolean {
  return ConnectError.from(error).code === Code.NotFound;
}

// What a rejected save shows. A request breaking the Input's rules names its fields. Any other
// failure is the form's, in the words the server chose, or else the given title.
export function saveFailure(error: unknown, fallbackTitle: string): FormErrors {
  if (ConnectError.from(error).code === Code.InvalidArgument) {
    return fieldViolations(error, { prefix: "input." });
  }
  return {
    form: preconditionMessage(error) || problemDetailsOf(error)?.title || fallbackTitle,
    fields: {},
  };
}
