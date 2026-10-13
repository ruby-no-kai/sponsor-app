import { Button, Combobox, Input, InputArea, Loader, Select } from "@cloudflare/kumo";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import type { ReactNode } from "react";
import { generatePath, useNavigate, useParams } from "react-router";
import { useSWRConfig } from "swr";
import type { AdminSponsorEvent } from "../../gen/rubykaigi/sponsor_app/admin_sponsor_events_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import type { SponsorshipSummary } from "../../gen/rubykaigi/sponsor_app/sponsorship_summary_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import type { FormErrors } from "../../lib/errors.ts";
import { erroredFields, errorsAt } from "../../lib/fieldErrors.ts";
import { idFromParam, idToInput } from "../../lib/forms.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { toastManager } from "../../lib/toast.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import {
  DateTimeInput,
  joined,
  SaveBar,
  SaveErrorBanner,
  Section,
  useFieldReveal,
} from "./FormParts.tsx";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";
import {
  FIELD_LABELS,
  SPONSOR_EVENT_LAYOUT,
  coHostChoices,
  sponsorEventInputFrom,
  sponsorEventValuesFrom,
} from "./sponsorEventForm.ts";
import type { SponsorEventTextField } from "./sponsorEventForm.ts";
import { EDITABLE_STATUSES, SPONSOR_EVENT_STATUS_LABELS } from "./sponsorEventView.ts";
import { labelOf } from "./sponsorshipView.ts";

export default function SponsorEventEditor() {
  const { slug = "", id = "" } = useParams();
  const sponsorEventId = idFromParam(id);
  if (sponsorEventId === undefined) return <NotFound />;
  return <EditSponsorEvent key={id} slug={slug} sponsorEventId={sponsorEventId} />;
}

function EditSponsorEvent({ slug, sponsorEventId }: { slug: string; sponsorEventId: bigint }) {
  const current = useRpc(AdminService.method.getSponsorEvent, {
    conferenceSlug: slug,
    sponsorEventId,
  });
  const conference = useRpc(AdminService.method.getConference, { conferenceSlug: slug });
  useConferenceTitle(slug, `Edit event: ${current.data?.sponsorEvent?.title ?? sponsorEventId}`);

  for (const { data, error } of [current, conference]) {
    if (error !== undefined && data === undefined) throw error;
  }
  if (current.data === undefined || conference.data === undefined) return <Loader size="lg" />;
  const event = current.data.sponsorEvent;
  if (event === undefined) throw new Error("GetSponsorEvent returned no event");

  return <Editor slug={slug} saved={event} sponsorships={conference.data.sponsorships} />;
}

function Editor({
  slug,
  saved,
  sponsorships,
}: {
  slug: string;
  saved: AdminSponsorEvent;
  sponsorships: readonly SponsorshipSummary[];
}) {
  const navigate = useNavigate();
  const { mutate } = useSWRConfig();
  const updateSponsorEvent = useRpcMutation(AdminService.method.updateSponsorEvent);
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();
  const eventPath = generatePath(paths.sponsorEvent, { slug, id: idToInput(saved.id) });
  const conferenceName = useConferenceName(slug);

  const form = useForm({
    defaultValues: sponsorEventValuesFrom(saved),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      const reject = (errors: FormErrors) => {
        rejection.reject(formApi, value, errors);
        const [first] = erroredFields(formApi.state.fieldMeta, SPONSOR_EVENT_LAYOUT);
        if (first !== undefined) reveal(first.path);
      };
      const built = sponsorEventInputFrom(value);
      if (built.kind === "invalid") {
        setSaveError(undefined);
        reject({ fields: built.fields });
        return;
      }
      let result: AdminSponsorEvent | undefined;
      try {
        const response = await updateSponsorEvent.trigger({
          conferenceSlug: slug,
          sponsorEventId: saved.id,
          input: built.input,
        });
        result = response.sponsorEvent;
      } catch (error) {
        setSaveError(error);
        reject(fieldViolations(error, { prefix: "input." }));
        return;
      }
      setSaveError(undefined);
      if (result === undefined) return;
      toastManager.add({ variant: "success", title: `Saved the event ${result.title}` });
      // Before leaving, so the event's pages are refetched rather than left stale in the cache.
      await mutate(
        (key) =>
          isRpcKeyOf(key, AdminService.method.getSponsorEvent) ||
          isRpcKeyOf(key, AdminService.method.listSponsorEvents) ||
          isRpcKeyOf(key, AdminService.method.getSponsorship),
      );
      await navigate(eventPath);
    },
  });

  const textField = (
    name: SponsorEventTextField,
    props: { description?: ReactNode; type?: string; className?: string } = {},
  ) => (
    <form.Field name={name}>
      {(field) => (
        <Input
          label={FIELD_LABELS[name]}
          {...props}
          data-field={field.name}
          value={field.state.value}
          onChange={(event) => field.handleChange(event.target.value)}
          onBlur={field.handleBlur}
          error={joined(field.state.meta.errors)}
        />
      )}
    </form.Field>
  );

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
          { label: "Events", href: generatePath(paths.sponsorEvents, { slug }) },
          { label: saved.title, href: eventPath },
        ]}
        title="Edit event"
      />

      <Section title="Event">
        {textField("title")}
        {textField("slug", {
          description: "Identifies the event on the conference website. Unique in the conference.",
          className: "font-mono",
        })}
        <form.Field name="startsAt">
          {(field) => (
            <div className="max-w-md">
              <DateTimeInput
                field={field}
                label={FIELD_LABELS.startsAt}
                description="The local time at the venue."
              />
            </div>
          )}
        </form.Field>
        {textField("url", { type: "url", description: "Starts with http:// or https://." })}
        {textField("linkName", {
          description: "Text that listings link the URL with, such as Registration.",
        })}
      </Section>

      <Section title="Details">
        <div className="grid items-start gap-4 md:grid-cols-2">
          {textField("price", { description: "Empty shows the event as free." })}
          {textField("capacity")}
          {textField("locationEn")}
          {textField("locationLocal")}
        </div>
      </Section>

      <Section title="Review">
        <form.Field name="status">
          {(field) => (
            <div data-field={field.name}>
              <Select
                label={FIELD_LABELS.status}
                className="min-w-60"
                value={field.state.value}
                onValueChange={(value) => {
                  if (value !== null) field.handleChange(value);
                }}
                items={EDITABLE_STATUSES.map((status) => ({
                  label: labelOf(SPONSOR_EVENT_STATUS_LABELS, status).text,
                  value: status,
                }))}
                description="An accepted event is listed on the conference website."
                error={joined(field.state.meta.errors)}
              />
            </div>
          )}
        </form.Field>
        <form.Field name="coHostSponsorshipIds">
          {(field) => {
            const choices = coHostChoices(sponsorships, {
              hostId: saved.sponsorship?.id,
              selected: field.state.value,
            });
            return (
              <form.Subscribe
                selector={(state) => errorsAt(state.fieldMeta, field.name, { items: true })}
              >
                {(errors) => (
                  <div data-field={field.name}>
                    <Combobox
                      label={FIELD_LABELS.coHostSponsorshipIds}
                      description="Further sponsorships hosting the event, listed in this order."
                      items={choices.ids}
                      multiple
                      value={field.state.value}
                      onValueChange={(value) => field.handleChange(value)}
                      itemToStringLabel={choices.label}
                      error={joined(errors)}
                    >
                      <Combobox.TriggerMultipleWithInput
                        placeholder="Add a co-host…"
                        renderItem={(id: string) => (
                          <Combobox.Chip key={id}>{choices.label(id)}</Combobox.Chip>
                        )}
                      />
                      <Combobox.Content>
                        <Combobox.Empty>No sponsorship matches.</Combobox.Empty>
                        <Combobox.List>
                          {(id: string) => (
                            <Combobox.Item key={id} value={id}>
                              {choices.label(id)}
                            </Combobox.Item>
                          )}
                        </Combobox.List>
                      </Combobox.Content>
                    </Combobox>
                  </div>
                )}
              </form.Subscribe>
            );
          }}
        </form.Field>
        <form.Field name="adminComment">
          {(field) => (
            <InputArea
              label={FIELD_LABELS.adminComment}
              description="Visible to the sponsor."
              data-field={field.name}
              autoResize
              minRows={3}
              maxRows={16}
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
          errored: erroredFields(state.fieldMeta, SPONSOR_EVENT_LAYOUT),
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
          </SaveBar>
        )}
      </form.Subscribe>
    </form>
  );
}
