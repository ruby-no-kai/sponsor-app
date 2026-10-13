import { Badge, Button, Empty, LayerCard, Link, Loader, Table, Text } from "@cloudflare/kumo";
import { StorefrontIcon } from "@phosphor-icons/react";
import { useForm, useSelector } from "@tanstack/react-form";
import { useEffect, useRef, useState } from "react";
import type { ReactNode } from "react";
import { generatePath, useParams } from "react-router";
import { useSWRConfig } from "swr";
import type {
  BoothAssignment,
  BoothAssignmentCandidate,
} from "../../gen/rubykaigi/sponsor_app/admin_booth_assignments_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { toastManager } from "../../lib/toast.ts";
import { paths } from "../paths.ts";
import { ErrorList, SaveBar, SaveErrorBanner, useFieldReveal } from "./FormParts.tsx";
import { useConferenceTitle } from "./conferenceTitle.ts";
import {
  BOOTH_ASSIGNMENT_LAYOUT,
  assignmentSummaryOf,
  boothAssignmentValuesFrom,
  candidateIdOf,
  sponsorshipOf,
  updateRequestFrom,
  withAssignment,
} from "./boothAssignmentForm.ts";

export default function BoothAssignmentEditor() {
  const { slug = "" } = useParams();
  const { data, error } = useRpc(AdminService.method.getBoothAssignment, { conferenceSlug: slug });
  const conference = useRpc(AdminService.method.getConference, { conferenceSlug: slug });
  const conferenceName = conference.data?.conference?.conference?.name ?? slug;
  useConferenceTitle(slug, "Booth assignment");

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const { boothAssignment } = data;
  if (boothAssignment === undefined)
    throw new Error("GetBoothAssignment returned no booth assignment");

  return <Editor key={slug} slug={slug} conferenceName={conferenceName} latest={boothAssignment} />;
}

function Editor({
  slug,
  conferenceName,
  latest,
}: {
  slug: string;
  conferenceName: string;
  // The newest answer SWR holds, which may first be one cached by an earlier visit.
  latest: BoothAssignment;
}) {
  const { mutate } = useSWRConfig();
  const updateBoothAssignment = useRpcMutation(AdminService.method.updateBoothAssignment);
  // What the server last answered, for the rows and the defaults, which must match each reset or
  // useForm restores the values from before it.
  const [saved, setSaved] = useState(latest);
  // The answer the rows were last taken from.
  const adopted = useRef(latest);
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();
  const allIds = saved.candidates.map(candidateIdOf);

  const form = useForm({
    defaultValues: boothAssignmentValuesFrom(saved),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      let result: BoothAssignment | undefined;
      try {
        const response = await updateBoothAssignment.trigger(updateRequestFrom(slug, value));
        result = response.boothAssignment;
      } catch (error) {
        setSaveError(error);
        rejection.reject(formApi, value, fieldViolations(error, { prefix: "input." }));
        const [first] = erroredFields(formApi.state.fieldMeta, BOOTH_ASSIGNMENT_LAYOUT);
        if (first !== undefined) reveal(first.path);
        return;
      }
      setSaveError(undefined);
      if (result === undefined) return;
      setSaved(result);
      formApi.reset(boothAssignmentValuesFrom(result));
      toastManager.add({
        variant: "success",
        title: "Saved the booth assignment",
        description: `${result.assignedCount} ${sponsors(result.assignedCount)} hold a booth.`,
      });
      await mutate(
        (key) =>
          isRpcKeyOf(key, AdminService.method.getBoothAssignment) ||
          isRpcKeyOf(key, AdminService.method.getConference) ||
          isRpcKeyOf(key, AdminService.method.getSponsorship) ||
          isRpcKeyOf(key, AdminService.method.listSponsorshipTableRows) ||
          isRpcKeyOf(key, AdminService.method.getOrganization),
      );
    },
  });

  const hasUnsavedChanges = useSelector(
    form.store,
    (state) => assignmentSummaryOf(saved, state.values).changedCount > 0,
  );

  // Saving replaces the whole set, so the rows follow a newer answer unless that would drop
  // unsaved changes.
  useEffect(() => {
    if (latest === adopted.current || hasUnsavedChanges) return;
    adopted.current = latest;
    setSaved(latest);
    form.reset(boothAssignmentValuesFrom(latest));
  }, [latest, hasUnsavedChanges, form]);

  return (
    <form
      ref={formRef}
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault();
        void rejection.submit(form);
      }}
    >
      <PageHeader
        crumbs={[{ label: conferenceName, href: generatePath(paths.conference, { slug }) }]}
        title="Booth assignment"
      />

      <div className="grid grid-cols-2 gap-4">
        <Figure
          label="Candidates"
          value={saved.candidateCount}
          detail={`Booth size ${saved.candidateBoothSize} in total. ${saved.requestingCount} ${
            saved.requestingCount === 1 ? "request" : "requests"
          }, counting sponsors awaiting acceptance.`}
        />
        <form.Subscribe selector={(state) => assignmentSummaryOf(saved, state.values)}>
          {({ assignedCount, assignedBoothSize, changedCount }) => (
            <Figure
              label="Assigned"
              value={assignedCount}
              detail={`Booth size ${assignedBoothSize} in total.`}
              badge={
                changedCount > 0 ? (
                  <Badge variant="warning">
                    {changedCount} unsaved {changedCount === 1 ? "change" : "changes"}
                  </Badge>
                ) : undefined
              }
            />
          )}
        </form.Subscribe>
      </div>

      {saved.candidates.length === 0 ? (
        <Empty
          icon={<StorefrontIcon size={32} />}
          title="No candidates"
          description="No accepted sponsor has asked for a booth."
        />
      ) : (
        <form.Field name="assignedSponsorshipIds">
          {(field) => {
            const assigned = new Set(field.state.value);
            return (
              <div className="flex flex-col gap-2" data-field={field.name}>
                <div className="flex flex-wrap gap-2">
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    onClick={() => field.handleChange(allIds)}
                  >
                    Select all
                  </Button>
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    onClick={() => field.handleChange([])}
                  >
                    Select none
                  </Button>
                </div>
                <form.Subscribe
                  selector={(state) =>
                    erroredFields(state.fieldMeta, BOOTH_ASSIGNMENT_LAYOUT)
                      .filter((error) => error.path === field.name)
                      .map((error) => error.message)
                  }
                >
                  {(errors) => <ErrorList errors={errors} />}
                </form.Subscribe>
                <LayerCard className="overflow-x-auto p-0">
                  <Table>
                    <Table.Header>
                      <Table.Row>
                        <Table.CheckHead
                          label="Assign a booth to every candidate"
                          checked={assigned.size > 0 && assigned.size === allIds.length}
                          indeterminate={assigned.size > 0 && assigned.size < allIds.length}
                          onCheckedChange={(checked) => field.handleChange(checked ? allIds : [])}
                        />
                        <Table.Head>Plan</Table.Head>
                        <Table.Head>Booth size</Table.Head>
                        <Table.Head>Sponsor</Table.Head>
                        <Table.Head>Request</Table.Head>
                      </Table.Row>
                    </Table.Header>
                    <Table.Body>
                      {saved.candidates.map((candidate) => {
                        const id = candidateIdOf(candidate);
                        return (
                          <CandidateRow
                            key={id}
                            slug={slug}
                            candidate={candidate}
                            assigned={assigned.has(id)}
                            onAssignedChange={(checked) =>
                              field.handleChange(withAssignment(field.state.value, id, checked))
                            }
                          />
                        );
                      })}
                    </Table.Body>
                  </Table>
                </LayerCard>
              </div>
            );
          }}
        </form.Field>
      )}

      {saved.candidates.length > 0 && (
        <form.Subscribe
          selector={(state) => ({
            formError: state.errorMap.onChange,
            errored: erroredFields(state.fieldMeta, BOOTH_ASSIGNMENT_LAYOUT),
            isSubmitting: state.isSubmitting,
            isDirty: state.isDirty,
          })}
        >
          {({ formError, errored, isSubmitting, isDirty }) => (
            <SaveBar
              isDirty={isDirty}
              banner={
                <SaveErrorBanner
                  formError={formError}
                  errored={errored}
                  error={saveError}
                  onShow={reveal}
                />
              }
            >
              <Button type="submit" variant="primary" loading={isSubmitting}>
                Save
              </Button>
              <Text variant="secondary" size="sm">
                Saving assigns booths to exactly the sponsors checked and takes them back from every
                other sponsorship of the conference, including those awaiting acceptance or
                withdrawn.
              </Text>
            </SaveBar>
          )}
        </form.Subscribe>
      )}
    </form>
  );
}

function CandidateRow({
  slug,
  candidate,
  assigned,
  onAssignedChange,
}: {
  slug: string;
  candidate: BoothAssignmentCandidate;
  assigned: boolean;
  onAssignedChange: (assigned: boolean) => void;
}) {
  const sponsorship = sponsorshipOf(candidate);
  const changed = assigned !== sponsorship.boothAssigned;

  return (
    <Table.Row variant={assigned ? "selected" : "default"}>
      <Table.CheckCell
        label={`Assign a booth to ${sponsorship.name}`}
        checked={assigned}
        onCheckedChange={onAssignedChange}
      />
      <Table.Cell>
        {candidate.planName ?? (
          <Text variant="secondary" as="span">
            <i>Other</i>
          </Text>
        )}
      </Table.Cell>
      <Table.Cell>{candidate.boothSize}</Table.Cell>
      <Table.Cell>
        {sponsorship.customizationName !== undefined && `${sponsorship.customizationName}: `}
        <Link href={generatePath(paths.sponsorship, { slug, id: sponsorship.id.toString() })}>
          {sponsorship.name}
        </Link>
      </Table.Cell>
      <Table.Cell>
        <span className="inline-flex flex-wrap gap-1">
          {candidate.boothRequested ? (
            <Badge variant="info">Requested</Badge>
          ) : (
            <Badge variant="warning">Not requested</Badge>
          )}
          {candidate.boothSize === 0 && <Badge variant="warning">Plan has no booth</Badge>}
          {changed && (
            <Badge variant="outline">{assigned ? "To be assigned" : "To be taken back"}</Badge>
          )}
        </span>
      </Table.Cell>
    </Table.Row>
  );
}

function Figure({
  label,
  value,
  detail,
  badge,
}: {
  label: string;
  value: number;
  detail: string;
  badge?: ReactNode;
}) {
  return (
    <LayerCard>
      <LayerCard.Primary className="flex flex-col gap-1">
        <Text variant="secondary">{label}</Text>
        <div className="flex flex-wrap items-baseline gap-x-2 gap-y-1">
          <Text variant="heading" size="lg" as="span">
            {value}
          </Text>
          <Text variant="secondary" as="span">
            {sponsors(value)}
          </Text>
          {badge}
        </div>
        <Text variant="secondary" size="sm">
          {detail}
        </Text>
      </LayerCard.Primary>
    </LayerCard>
  );
}

function sponsors(count: number): string {
  return count === 1 ? "sponsor" : "sponsors";
}
