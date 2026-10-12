import { getOption, hasOption } from "@bufbuild/protobuf";
import { anyUnpack } from "@bufbuild/protobuf/wkt";
import { Code, ConnectError } from "@connectrpc/connect";
import { BadRequestSchema, RequestInfoSchema } from "../gen/google/rpc/error_details_pb.ts";
import type { BadRequest, BadRequest_FieldViolation } from "../gen/google/rpc/error_details_pb.ts";
import { ProblemTypeSchema, problem_type } from "../gen/rubykaigi/sponsor_app/problem_pb.ts";
import type { ProblemType } from "../gen/rubykaigi/sponsor_app/problem_pb.ts";
import { ProblemDetailsSchema } from "../gen/protobufable/problem_details_pb.ts";
import type { ProblemDetails } from "../gen/protobufable/problem_details_pb.ts";

// problem.proto: a problem's `type` is its ProblemType value's `uri` appended to this prefix.
export const PROBLEM_TYPE_PREFIX = "https://sponsorships.rubykaigi.org/problems/";

// Values may share a uri, and the first one listed answers for it.
const PROBLEM_TYPES: ReadonlyMap<string, ProblemType> = ProblemTypeSchema.values.reduce(
  (types, value) => {
    if (!hasOption(value, problem_type)) return types;
    const type = PROBLEM_TYPE_PREFIX + getOption(value, problem_type).uri;
    if (!types.has(type)) types.set(type, value.number as ProblemType);
    return types;
  },
  new Map<string, ProblemType>(),
);

export function problemDetailsOf(error: unknown): ProblemDetails | undefined {
  return ConnectError.from(error).findDetails(ProblemDetailsSchema)[0];
}

// The ProblemType a problem error was raised as, or undefined for an error that is no problem,
// such as a malformed request.
export function problemTypeOf(error: unknown): ProblemType | undefined {
  const type = problemDetailsOf(error)?.type;
  return type === undefined ? undefined : PROBLEM_TYPES.get(type);
}

// Enum value name, such as "NOT_FOUND", for display.
export function problemTypeName(type: ProblemType): string {
  return ProblemTypeSchema.value[type]?.localName ?? String(type);
}

// The ID to quote when reporting the error. A call the transport refuses outright carries none.
export function requestIdOf(error: unknown): string | undefined {
  return ConnectError.from(error).findDetails(RequestInfoSchema)[0]?.requestId || undefined;
}

// Whether trying again may help: the service or the network failed, rather than refusing the
// request.
export function isRetryable(error: unknown): boolean {
  const { code } = ConnectError.from(error);
  return code === Code.Unavailable || code === Code.Internal || code === Code.Unknown;
}

// The sentence the server worded for a precondition that does not hold, such as a conference
// without ticketing. Undefined for any other error.
export function preconditionDetail(error: unknown): string | undefined {
  if (ConnectError.from(error).code !== Code.FailedPrecondition) return undefined;
  return problemDetailsOf(error)?.detail || undefined;
}

// Whether the server answered that what the request names does not exist.
export function isNotFoundError(error: unknown): boolean {
  return error instanceof ConnectError && error.code === Code.NotFound;
}

// Connect code name, such as "NotFound".
export function codeName(error: unknown): string {
  const { code } = ConnectError.from(error);
  return Code[code] ?? String(code);
}

// A google.rpc.BadRequest arrives as a detail of its own, or inside a problem's information.
function badRequestsOf(error: ConnectError): BadRequest[] {
  const nested = error
    .findDetails(ProblemDetailsSchema)
    .flatMap((details) => details.information.map((any) => anyUnpack(any, BadRequestSchema)))
    .filter((badRequest) => badRequest !== undefined);
  return [...error.findDetails(BadRequestSchema), ...nested];
}

// protovalidate calls the field "value", which reads oddly under the field's own label.
function describe(violation: BadRequest_FieldViolation): string {
  if (violation.reason === "REQUIRED") return "is required";
  return violation.description.replace(/^value (?=must |does |is )/, "");
}

// The errors a TanStack Form validator returns: messages by field path, and a form-level message.
export type FormErrors = {
  form?: string;
  fields: Record<string, string>;
};

// Maps the field violations of an error onto a form's fields. Paths arrive in the encoding the
// request used, lowerCamelCase for the JSON the SPA sends. With a prefix, such as "input.", only
// violations under it name a form field, and the prefix is dropped. Any other violation, and an
// error without violations, becomes the form-level message.
export function fieldViolations(
  error: unknown,
  { prefix = "" }: { prefix?: string } = {},
): FormErrors {
  const connectError = ConnectError.from(error);
  const fields: Record<string, string> = {};
  const formMessages: string[] = [];

  for (const violation of badRequestsOf(connectError).flatMap(
    (badRequest) => badRequest.fieldViolations,
  )) {
    const field = violation.field.startsWith(prefix) ? violation.field.slice(prefix.length) : "";
    const description = describe(violation);
    if (field === "") {
      formMessages.push(
        violation.field === "" ? description : `${violation.field}: ${description}`,
      );
      continue;
    }
    const existing = fields[field];
    fields[field] = existing === undefined ? description : `${existing}; ${description}`;
  }

  if (formMessages.length === 0 && Object.keys(fields).length === 0) {
    formMessages.push(connectError.rawMessage);
  }
  return formMessages.length === 0 ? { fields } : { form: formMessages.join("; "), fields };
}
