import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import { Code, ConnectError } from "@connectrpc/connect";
import { BadRequestSchema } from "../../gen/google/rpc/error_details_pb.ts";
import { ProblemDetailsSchema } from "../../gen/protobufable/problem_details_pb.ts";
import { isNotFound, preconditionMessage, saveFailure } from "./sponsorSave.ts";

function problem(code: Code, detail: string, title = "Title"): ConnectError {
  return new ConnectError("raw", code, undefined, [
    { desc: ProblemDetailsSchema, value: create(ProblemDetailsSchema, { title, detail }) },
  ]);
}

describe("preconditionMessage", () => {
  it("is the detail of a failed precondition", () => {
    assert.equal(preconditionMessage(problem(Code.FailedPrecondition, "Not open")), "Not open");
  });

  it("is nothing for any other error", () => {
    assert.equal(preconditionMessage(problem(Code.NotFound, "x")), undefined);
    assert.equal(preconditionMessage(new Error("boom")), undefined);
  });
});

describe("isNotFound", () => {
  it("tells a missing resource", () => {
    assert.ok(isNotFound(problem(Code.NotFound, "x")));
    assert.ok(!isNotFound(problem(Code.Aborted, "x")));
  });
});

describe("saveFailure", () => {
  it("maps rule violations onto the Input's fields", () => {
    const error = new ConnectError("raw", Code.InvalidArgument, undefined, [
      {
        desc: BadRequestSchema,
        value: create(BadRequestSchema, {
          fieldViolations: [{ field: "input.title", description: "value must not be blank" }],
        }),
      },
    ]);
    assert.deepEqual(saveFailure(error, "fallback"), {
      fields: { title: "must not be blank" },
    });
  });

  it("words a failed precondition as the server did", () => {
    assert.deepEqual(saveFailure(problem(Code.FailedPrecondition, "Closed"), "fallback"), {
      form: "Closed",
      fields: {},
    });
  });

  it("falls back to the problem's title, then the given one", () => {
    assert.deepEqual(saveFailure(problem(Code.Aborted, "d", "Conflict"), "fallback"), {
      form: "Conflict",
      fields: {},
    });
    assert.deepEqual(saveFailure(new Error("boom"), "fallback"), { form: "fallback", fields: {} });
  });
});
