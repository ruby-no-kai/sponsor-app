import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toBinary } from "@bufbuild/protobuf";
import type { DescMessage, MessageInitShape } from "@bufbuild/protobuf";
import { anyPack } from "@bufbuild/protobuf/wkt";
import { Code, ConnectError } from "@connectrpc/connect";
import { BadRequestSchema, RequestInfoSchema } from "../gen/google/rpc/error_details_pb.ts";
import { ProblemType } from "../gen/rubykaigi/sponsor_app/problem_pb.ts";
import { ProblemDetailsSchema } from "../gen/protobufable/problem_details_pb.ts";
import {
  codeName,
  fieldViolations,
  isNotFoundError,
  preconditionDetail,
  isRetryable,
  problemTypeName,
  problemTypeOf,
  requestIdOf,
} from "./errors.ts";

// Details arrive from the wire as type names and bytes, which findDetails decodes.
function wireDetail<Desc extends DescMessage>(schema: Desc, init: MessageInitShape<Desc>) {
  return { type: schema.typeName, value: toBinary(schema, create(schema, init)) };
}

function connectError(code: Code, message: string, details: { type: string; value: Uint8Array }[]) {
  const error = new ConnectError(message, code);
  error.details.push(...details);
  return error;
}

const badRequest = (
  ...fieldViolations: { field: string; description: string; reason?: string }[]
) => create(BadRequestSchema, { fieldViolations });

describe("problemTypeOf", () => {
  it("maps the published type back to its ProblemType", () => {
    const error = connectError(Code.NotFound, "No conference", [
      wireDetail(ProblemDetailsSchema, {
        type: "https://sponsorships.rubykaigi.org/problems/not-found",
        status: 404,
      }),
    ]);

    assert.equal(problemTypeOf(error), ProblemType.NOT_FOUND);
    assert.equal(problemTypeName(ProblemType.NOT_FOUND), "NOT_FOUND");
  });

  it("is undefined for an unknown type and for an error with no problem", () => {
    const unknown = connectError(Code.Internal, "boom", [
      wireDetail(ProblemDetailsSchema, { type: "https://example.invalid/problems/other" }),
    ]);

    assert.equal(problemTypeOf(unknown), undefined);
    assert.equal(problemTypeOf(connectError(Code.InvalidArgument, "bad", [])), undefined);
  });
});

describe("requestIdOf", () => {
  it("reads google.rpc.RequestInfo", () => {
    const error = connectError(Code.Internal, "boom", [
      wireDetail(RequestInfoSchema, { requestId: "req-1" }),
    ]);

    assert.equal(requestIdOf(error), "req-1");
    assert.equal(requestIdOf(new ConnectError("plain")), undefined);
  });
});

describe("codeName", () => {
  it("names the Connect code", () => {
    assert.equal(codeName(new ConnectError("x", Code.PermissionDenied)), "PermissionDenied");
  });
});

describe("isRetryable", () => {
  it("is true for a failing service or network", () => {
    for (const code of [Code.Unavailable, Code.Internal, Code.Unknown]) {
      assert.ok(isRetryable(new ConnectError("x", code)));
    }
    assert.ok(isRetryable(new Error("offline")));
  });

  it("is false for a refused request", () => {
    for (const code of [Code.FailedPrecondition, Code.NotFound, Code.PermissionDenied]) {
      assert.ok(!isRetryable(new ConnectError("x", code)));
    }
  });
});

describe("preconditionDetail", () => {
  it("is the problem's detail for a failed precondition", () => {
    const error = connectError(Code.FailedPrecondition, "x", [
      wireDetail(ProblemDetailsSchema, { detail: "No ticketing." }),
    ]);
    assert.equal(preconditionDetail(error), "No ticketing.");
  });

  it("is undefined for another code or a missing detail", () => {
    const detail = wireDetail(ProblemDetailsSchema, { detail: "No." });
    assert.equal(preconditionDetail(connectError(Code.NotFound, "x", [detail])), undefined);
    assert.equal(preconditionDetail(connectError(Code.FailedPrecondition, "x", [])), undefined);
  });
});

describe("isNotFoundError", () => {
  it("is true for a not_found answer only", () => {
    assert.ok(isNotFoundError(new ConnectError("x", Code.NotFound)));
    assert.ok(!isNotFoundError(new ConnectError("x", Code.Aborted)));
    assert.ok(!isNotFoundError(new Error("x")));
  });
});

describe("fieldViolations", () => {
  it("maps a direct BadRequest onto fields", () => {
    const error = connectError(Code.InvalidArgument, "invalid", [
      wireDetail(BadRequestSchema, {
        fieldViolations: [
          { field: "conferenceSlug", description: "must match pattern" },
          { field: "conferenceSlug", description: "must not be empty" },
        ],
      }),
    ]);

    assert.deepEqual(fieldViolations(error), {
      fields: { conferenceSlug: "must match pattern; must not be empty" },
    });
  });

  it("reads a BadRequest inside a problem's information", () => {
    const error = connectError(Code.InvalidArgument, "Record invalid", [
      wireDetail(ProblemDetailsSchema, {
        type: "https://sponsorships.rubykaigi.org/problems/invalid-record",
        information: [
          anyPack(
            BadRequestSchema,
            badRequest(
              { field: "input.name", description: "can't be blank" },
              { field: "input.plans[0].rank", description: "must be positive" },
              { field: "", description: "Sponsorship is closed" },
            ),
          ),
        ],
      }),
    ]);

    assert.deepEqual(fieldViolations(error, { prefix: "input." }), {
      form: "Sponsorship is closed",
      fields: { name: "can't be blank", "plans[0].rank": "must be positive" },
    });
  });

  it("puts violations outside the prefix on the form", () => {
    const error = connectError(Code.InvalidArgument, "invalid", [
      wireDetail(
        BadRequestSchema,
        badRequest(
          { field: "conferenceSlug", description: "must not be empty" },
          { field: "input.name", description: "can't be blank" },
        ),
      ),
    ]);

    assert.deepEqual(fieldViolations(error, { prefix: "input." }), {
      form: "conferenceSlug: must not be empty",
      fields: { name: "can't be blank" },
    });
  });

  it('drops protovalidate\'s "value", saying a missing field is required', () => {
    const error = connectError(Code.InvalidArgument, "invalid", [
      wireDetail(
        BadRequestSchema,
        badRequest(
          {
            field: "input.fallbackOptions[0].value",
            reason: "REQUIRED",
            description: "value is required",
          },
          { field: "conferenceSlug", reason: "REQUIRED", description: "value is required" },
          {
            field: "input.locale",
            reason: "STRING_IN",
            description: "value must be in list [en, ja]",
          },
          {
            field: "input.name",
            reason: "NAME_NOT_BLANK",
            description: "value must not be blank",
          },
          {
            field: "input.price",
            reason: "PRICE_FORMAT",
            description: "must be an amount such as 1000 or 1000.50",
          },
        ),
      ),
    ]);

    assert.deepEqual(fieldViolations(error, { prefix: "input." }), {
      form: "conferenceSlug: is required",
      fields: {
        "fallbackOptions[0].value": "is required",
        locale: "must be in list [en, ja]",
        name: "must not be blank",
        price: "must be an amount such as 1000 or 1000.50",
      },
    });
  });

  it("falls back to the error's message", () => {
    assert.deepEqual(fieldViolations(new ConnectError("Conflict", Code.Aborted)), {
      form: "Conflict",
      fields: {},
    });
  });
});
