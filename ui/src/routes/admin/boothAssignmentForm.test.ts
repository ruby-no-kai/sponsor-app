import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create, toJson } from "@bufbuild/protobuf";
import {
  AdminServiceUpdateBoothAssignmentRequestSchema,
  BoothAssignmentSchema,
} from "../../gen/rubykaigi/sponsor_app/admin_booth_assignments_pb.ts";
import {
  assignmentSummaryOf,
  boothAssignmentValuesFrom,
  updateRequestFrom,
  withAssignment,
} from "./boothAssignmentForm.ts";

const boothAssignment = create(BoothAssignmentSchema, {
  candidateCount: 3,
  candidateBoothSize: 7,
  requestingCount: 4,
  assignedCount: 2,
  assignedBoothSize: 6,
  candidates: [
    { sponsorship: { id: 11n, name: "Large", boothAssigned: true }, boothSize: 4 },
    { sponsorship: { id: 12n, name: "Small", boothAssigned: true }, boothSize: 2 },
    { sponsorship: { id: 13n, name: "Waiting", boothAssigned: false }, boothSize: 1 },
  ],
});

describe("boothAssignmentValuesFrom", () => {
  it("checks the candidates holding a booth", () => {
    assert.deepEqual(boothAssignmentValuesFrom(boothAssignment), {
      assignedSponsorshipIds: ["11", "12"],
    });
  });
});

describe("withAssignment", () => {
  it("adds or drops one ID, keeping the others in their order", () => {
    assert.deepEqual(withAssignment(["11", "12"], "13", true), ["11", "12", "13"]);
    assert.deepEqual(withAssignment(["11", "12"], "11", false), ["12"]);
  });

  it("lists an ID checked twice once", () => {
    assert.deepEqual(withAssignment(["11", "12"], "11", true), ["12", "11"]);
  });
});

describe("assignmentSummaryOf", () => {
  it("matches the server's figures for the values it was saved from", () => {
    assert.deepEqual(
      assignmentSummaryOf(boothAssignment, boothAssignmentValuesFrom(boothAssignment)),
      { assignedCount: 2, assignedBoothSize: 6, changedCount: 0 },
    );
  });

  it("counts the candidates the values assign or take back", () => {
    assert.deepEqual(
      assignmentSummaryOf(boothAssignment, { assignedSponsorshipIds: ["12", "13"] }),
      { assignedCount: 2, assignedBoothSize: 3, changedCount: 2 },
    );
    assert.deepEqual(assignmentSummaryOf(boothAssignment, { assignedSponsorshipIds: [] }), {
      assignedCount: 0,
      assignedBoothSize: 0,
      changedCount: 2,
    });
  });
});

describe("updateRequestFrom", () => {
  it("sends the full set, an empty one included", () => {
    const request = (ids: string[]) =>
      toJson(
        AdminServiceUpdateBoothAssignmentRequestSchema,
        create(
          AdminServiceUpdateBoothAssignmentRequestSchema,
          updateRequestFrom("rubykaigi2048", { assignedSponsorshipIds: ids }),
        ),
      );

    assert.deepEqual(request(["13", "11"]), {
      conferenceSlug: "rubykaigi2048",
      input: { assignedSponsorshipIds: ["13", "11"] },
    });
    assert.deepEqual(request([]), { conferenceSlug: "rubykaigi2048", input: {} });
  });
});
