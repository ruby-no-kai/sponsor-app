import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { Code, ConnectError } from "@connectrpc/connect";
import { AdminService } from "../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { isRetryable, rpcKey, signInUrl } from "./rpc.ts";

describe("signInUrl", () => {
  it("sends staff pages to the staff sign-in, coming back to the same page", () => {
    assert.equal(
      signInUrl({ pathname: "/admin/conferences/rk26", search: "?tab=plans" }),
      "/admin/session/new?back_to=%2Fadmin%2Fconferences%2Frk26%3Ftab%3Dplans",
    );
    assert.equal(
      signInUrl({ pathname: "/admin", search: "" }),
      "/admin/session/new?back_to=%2Fadmin",
    );
  });

  it("sends every other page to the sponsor sign-in", () => {
    assert.equal(
      signInUrl({ pathname: "/conferences/rk26/sponsorship", search: "" }),
      "/session/new?back_to=%2Fconferences%2Frk26%2Fsponsorship",
    );
    assert.equal(
      signInUrl({ pathname: "/administrivia", search: "" }),
      "/session/new?back_to=%2Fadministrivia",
    );
  });
});

describe("rpcKey", () => {
  it("keys a call by service, method and the input's JSON", () => {
    assert.deepEqual(rpcKey(AdminService.method.getConference, { conferenceSlug: "rk26" }), [
      "rubykaigi.sponsor_app.AdminService",
      "GetConference",
      '{"conferenceSlug":"rk26"}',
    ]);
  });
});

describe("isRetryable", () => {
  it("gives up on answers a retry cannot change", () => {
    assert.ok(!isRetryable(new ConnectError("x", Code.PermissionDenied)));
    assert.ok(!isRetryable(new ConnectError("x", Code.InvalidArgument)));
    assert.ok(isRetryable(new ConnectError("x", Code.Unavailable)));
    assert.ok(isRetryable(new TypeError("Failed to fetch")));
  });
});
