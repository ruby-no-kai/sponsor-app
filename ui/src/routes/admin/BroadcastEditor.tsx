import { Banner, Button, Input, InputArea, Loader, Text } from "@cloudflare/kumo";
import { LockSimpleIcon } from "@phosphor-icons/react";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import { generatePath, useNavigate, useParams } from "react-router";
import { useSWRConfig } from "swr";
import type { AdminBroadcast } from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import { idFromParam } from "../../lib/forms.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { toastManager } from "../../lib/toast.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import { joined, SaveBar, SaveErrorBanner, Section, useFieldReveal } from "./FormParts.tsx";
import {
  BROADCAST_LAYOUT,
  FIELD_LABELS,
  broadcastInputFrom,
  broadcastValuesFrom,
} from "./broadcastForm.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";

// One page for new and edit, at the paths HAML serves them.
export default function BroadcastEditor() {
  const { slug = "", id } = useParams();
  if (id === undefined) return <NewBroadcast slug={slug} />;
  const broadcastId = idFromParam(id);
  if (broadcastId === undefined) return <NotFound />;
  return <EditBroadcast key={id} slug={slug} broadcastId={broadcastId} />;
}

function NewBroadcast({ slug }: { slug: string }) {
  useConferenceTitle(slug, "New broadcast");
  return <Editor slug={slug} saved={undefined} />;
}

function EditBroadcast({ slug, broadcastId }: { slug: string; broadcastId: bigint }) {
  const { data, error } = useRpc(AdminService.method.getBroadcast, {
    conferenceSlug: slug,
    broadcastId,
  });
  useConferenceTitle(slug, `Edit broadcast: ${data?.broadcast?.campaign ?? broadcastId}`);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  return <Editor slug={slug} saved={data.broadcast} />;
}

function Editor({ slug, saved }: { slug: string; saved: AdminBroadcast | undefined }) {
  const conferenceName = useConferenceName(slug);
  const navigate = useNavigate();
  const { mutate } = useSWRConfig();
  const createBroadcast = useRpcMutation(AdminService.method.createBroadcast);
  const updateBroadcast = useRpcMutation(AdminService.method.updateBroadcast);
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();
  const isLocked = saved?.contentLocked ?? false;

  const form = useForm({
    defaultValues: broadcastValuesFrom(saved),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      const input = broadcastInputFrom(value);
      let result: AdminBroadcast | undefined;
      try {
        const response =
          saved === undefined
            ? await createBroadcast.trigger({ conferenceSlug: slug, input })
            : await updateBroadcast.trigger({
                conferenceSlug: slug,
                broadcastId: saved.id,
                input,
              });
        result = response.broadcast;
      } catch (error) {
        setSaveError(error);
        rejection.reject(formApi, value, fieldViolations(error, { prefix: "input." }));
        const [first] = erroredFields(formApi.state.fieldMeta, BROADCAST_LAYOUT);
        if (first !== undefined) reveal(first.path);
        return;
      }
      setSaveError(undefined);
      if (result === undefined) return;
      toastManager.add({
        variant: "success",
        title: `${saved === undefined ? "Created" : "Saved"} the broadcast ${result.campaign}`,
      });
      // Before leaving, so the broadcast's page is refetched rather than left stale in the cache.
      await mutate(
        (key) =>
          isRpcKeyOf(key, AdminService.method.listBroadcasts) ||
          isRpcKeyOf(key, AdminService.method.getBroadcast),
      );
      await navigate(generatePath(paths.broadcast, { slug, id: result.id.toString() }));
    },
  });

  const back =
    saved === undefined
      ? generatePath(paths.broadcasts, { slug })
      : generatePath(paths.broadcast, { slug, id: saved.id.toString() });

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
        crumbs={[
          { label: conferenceName, href: generatePath(paths.conference, { slug }) },
          { label: "Broadcasts", href: generatePath(paths.broadcasts, { slug }) },
          ...(saved === undefined ? [] : [{ label: saved.campaign, href: back }]),
        ]}
        title={saved === undefined ? "New broadcast" : "Edit broadcast"}
      />

      <Section title="Campaign">
        <form.Field name="campaign">
          {(field) => (
            <Input
              label={FIELD_LABELS.campaign}
              description="What organizers call the broadcast, unique within the conference. Recipients never see it."
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        <form.Field name="description">
          {(field) => (
            <Input
              label={FIELD_LABELS.description}
              description="Notes for organizers. Optional."
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
      </Section>

      <Section title="Email">
        {isLocked && (
          <Banner
            icon={<LockSimpleIcon />}
            title="Title and body are fixed"
            description="The broadcast has been dispatched, so some recipients may have it already."
          />
        )}
        <form.Field name="title">
          {(field) => (
            <Input
              label={FIELD_LABELS.title}
              description="The subject, after the conference's name in brackets."
              data-field={field.name}
              disabled={isLocked}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        <form.Field name="body">
          {(field) => (
            <InputArea
              label={FIELD_LABELS.body}
              description="Markdown supported. @LOGIN@ becomes a sign-in link to the recipient's sponsorship."
              data-field={field.name}
              disabled={isLocked}
              autoResize
              minRows={10}
              maxRows={40}
              className="font-mono"
              value={field.state.value}
              onValueChange={field.handleChange}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
      </Section>

      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          errored: erroredFields(state.fieldMeta, BROADCAST_LAYOUT),
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
              {saved === undefined ? "Create" : "Save"}
            </Button>
          </SaveBar>
        )}
      </form.Subscribe>
    </form>
  );
}
