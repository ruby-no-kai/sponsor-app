import type { MessageInitShape } from "@bufbuild/protobuf";
import type {
  AdminServiceUpdateBoothAssignmentRequestSchema,
  BoothAssignment,
  BoothAssignmentCandidate,
} from "../../gen/rubykaigi/sponsor_app/admin_booth_assignments_pb.ts";
import type { SponsorshipSummary } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";
import { idFromInput, idToInput } from "../../lib/forms.ts";

// Named after BoothAssignmentInput's JSON fields, so a google.rpc.BadRequest field path below
// "input." is the name of the form field it concerns.
export type BoothAssignmentValues = {
  // Sponsorship IDs of the candidates to hold a booth, as idToInput spells them.
  assignedSponsorshipIds: string[];
};

export const BOOTH_ASSIGNMENT_LAYOUT: FieldLayout = {
  labels: { assignedSponsorshipIds: "Booths" },
};

export function sponsorshipOf(candidate: BoothAssignmentCandidate): SponsorshipSummary {
  const { sponsorship } = candidate;
  if (sponsorship === undefined) throw new Error("a booth assignment candidate has no sponsorship");
  return sponsorship;
}

export function candidateIdOf(candidate: BoothAssignmentCandidate): string {
  return idToInput(sponsorshipOf(candidate).id);
}

export function boothAssignmentValuesFrom(boothAssignment: BoothAssignment): BoothAssignmentValues {
  return {
    assignedSponsorshipIds: boothAssignment.candidates
      .filter((candidate) => sponsorshipOf(candidate).boothAssigned)
      .map(candidateIdOf),
  };
}

// The IDs with one candidate's checkbox set as checked, keeping the others in their order.
export function withAssignment(ids: readonly string[], id: string, assigned: boolean): string[] {
  const others = ids.filter((other) => other !== id);
  return assigned ? [...others, id] : others;
}

export type AssignmentSummary = {
  assignedCount: number;
  assignedBoothSize: number;
  // Candidates whose booth the values would assign or take back.
  changedCount: number;
};

// The assigned figures of the booth assignment as the values would leave it.
export function assignmentSummaryOf(
  boothAssignment: BoothAssignment,
  values: BoothAssignmentValues,
): AssignmentSummary {
  const assigned = new Set(values.assignedSponsorshipIds);
  const summary: AssignmentSummary = { assignedCount: 0, assignedBoothSize: 0, changedCount: 0 };
  for (const candidate of boothAssignment.candidates) {
    const isAssigned = assigned.has(candidateIdOf(candidate));
    if (isAssigned) {
      summary.assignedCount += 1;
      summary.assignedBoothSize += candidate.boothSize;
    }
    if (isAssigned !== sponsorshipOf(candidate).boothAssigned) summary.changedCount += 1;
  }
  return summary;
}

export function updateRequestFrom(
  conferenceSlug: string,
  values: BoothAssignmentValues,
): MessageInitShape<typeof AdminServiceUpdateBoothAssignmentRequestSchema> {
  return {
    conferenceSlug,
    input: { assignedSponsorshipIds: values.assignedSponsorshipIds.map(idFromInput) },
  };
}
