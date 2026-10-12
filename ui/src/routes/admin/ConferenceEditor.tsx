import { Banner, Button, Checkbox, Input, Link, Loader, Text } from "@cloudflare/kumo";
import { WarningIcon } from "@phosphor-icons/react";
import { useForm } from "@tanstack/react-form";
import { useRef, useState } from "react";
import { generatePath, useNavigate, useParams } from "react-router";
import { useSWRConfig } from "swr";
import type { AdminConference } from "../../gen/rubykaigi/sponsor_app/admin_conference_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import type { FormErrors } from "../../lib/errors.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { toastManager } from "../../lib/toast.ts";
import { paths } from "../paths.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import {
  DateTimeInput,
  joined,
  SaveBar,
  SaveErrorBanner,
  Section,
  useFieldReveal,
} from "./FormParts.tsx";
import {
  CONFERENCE_LAYOUT,
  DATE_TIME_FIELDS,
  FIELD_LABELS,
  formValuesFrom,
  inputFrom,
} from "./conferenceForm.ts";
import type { ConferenceValues } from "./conferenceForm.ts";

// One page for new and edit, at the paths of the HAML pages it replaces.
export default function ConferenceEditor() {
  const { slug } = useParams();
  const current = useRpc(
    AdminService.method.getConference,
    slug === undefined ? null : { conferenceSlug: slug },
  );
  const viewer = useRpc(AdminService.method.getViewer, {}).data?.staff;
  useDocumentTitle(
    slug === undefined ? "New conference" : "Edit conference",
    current.data?.conference?.conference?.name ?? slug,
  );

  if (current.error !== undefined && current.data === undefined) throw current.error;
  if (slug !== undefined && current.data === undefined) return <Loader size="lg" />;

  return (
    <Editor
      key={slug ?? ""}
      saved={current.data?.conference}
      isRestricted={viewer?.restricted ?? false}
    />
  );
}

type CheckboxField = {
  name: keyof ConferenceValues &
    ("noPlanAllowed" | "additionalAttendeesRegistrationOpen" | "hidden" | "allowRestrictedAccess");
  description?: string;
};

function Editor({
  saved: initiallySaved,
  isRestricted,
}: {
  saved: AdminConference | undefined;
  isRestricted: boolean;
}) {
  const navigate = useNavigate();
  const { mutate } = useSWRConfig();
  const createConference = useRpcMutation(AdminService.method.createConference);
  const updateConference = useRpcMutation(AdminService.method.updateConference);
  // What the server last answered: the ref for the next save, the state for the defaults, which
  // must match each reset or useForm restores the values from before it.
  const lastSaved = useRef(initiallySaved);
  const [saved, setSaved] = useState(initiallySaved);
  const savedSlug = saved?.conference?.slug;
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();

  const form = useForm({
    defaultValues: formValuesFrom(saved),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      const reject = (errors: FormErrors) => {
        rejection.reject(formApi, value, errors);
        const [first] = erroredFields(formApi.state.fieldMeta, CONFERENCE_LAYOUT);
        if (first !== undefined) reveal(first.path);
      };
      const built = inputFrom(value);
      if (built.kind === "invalid") {
        setSaveError(undefined);
        reject({ fields: built.fields });
        return;
      }
      const slug = lastSaved.current?.conference?.slug;
      let result: AdminConference | undefined;
      try {
        const response =
          slug === undefined
            ? await createConference.trigger({ input: built.input })
            : await updateConference.trigger({ conferenceSlug: slug, input: built.input });
        result = response.conference;
      } catch (error) {
        setSaveError(error);
        reject(fieldViolations(error, { prefix: "input." }));
        return;
      }
      setSaveError(undefined);
      const conference = result?.conference;
      if (result === undefined || conference === undefined) return;
      lastSaved.current = result;
      setSaved(result);
      formApi.reset(formValuesFrom(result));
      toastManager.add({ variant: "success", title: `Saved ${conference.name}` });
      // Leaves a page whose slug moved before revalidating, which would answer not_found there.
      if (initiallySaved === undefined) {
        await navigate(generatePath(paths.conference, { slug: conference.slug }));
      } else if (conference.slug !== initiallySaved.conference?.slug) {
        await navigate(generatePath(paths.conferenceEdit, { slug: conference.slug }), {
          replace: true,
        });
      }
      await mutate(
        (key) =>
          isRpcKeyOf(key, AdminService.method.listConferences) ||
          isRpcKeyOf(key, AdminService.method.getConference),
      );
    },
  });

  const checkboxField = ({ name, description }: CheckboxField) => (
    <form.Field name={name}>
      {(field) => (
        <div className="flex flex-col gap-1" data-field={field.name}>
          <Checkbox
            label={FIELD_LABELS[name]}
            checked={field.state.value}
            onCheckedChange={(checked) => field.handleChange(checked)}
          />
          {description !== undefined && (
            <Text variant="secondary" size="sm">
              {description}
            </Text>
          )}
          <FieldError errors={field.state.meta.errors} />
        </div>
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
        crumbs={
          savedSlug === undefined || saved?.conference === undefined
            ? [{ label: "Conferences", href: paths.conferences }]
            : [
                {
                  label: saved.conference.name,
                  href: generatePath(paths.conference, { slug: savedSlug }),
                },
              ]
        }
        title={saved?.conference === undefined ? "New conference" : "Edit conference"}
      />

      {isRestricted && (
        <Banner
          variant="alert"
          icon={<WarningIcon />}
          title="Restricted staff cannot save conferences"
          description="Ask a staff member with full access to make this change."
        />
      )}

      <Section title="Conference">
        <form.Field name="name">
          {(field) => (
            <Input
              label={FIELD_LABELS.name}
              placeholder="RubyKaigi 2026"
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        <form.Field name="slug">
          {(field) => (
            <Input
              label={FIELD_LABELS.slug}
              description="Used in URLs: lowercase letters, digits, - and _."
              placeholder="rubykaigi2026"
              className="font-mono"
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        <form.Field name="contactEmailAddress">
          {(field) => (
            <Input
              label={FIELD_LABELS.contactEmailAddress}
              description="Where sponsors reach the organizers."
              type="email"
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
      </Section>

      <Section title="Schedule">
        <Text variant="secondary">Times are in your browser's time zone.</Text>
        <div className="grid gap-4 md:grid-cols-2">
          {DATE_TIME_FIELDS.map(({ name, description }) => (
            <form.Field key={name} name={name}>
              {(field) => (
                <DateTimeInput field={field} label={FIELD_LABELS[name]} description={description} />
              )}
            </form.Field>
          ))}
        </div>
      </Section>

      <Section title="Applications">
        {checkboxField({
          name: "noPlanAllowed",
        })}
        <form.Field name="boothCapacity">
          {(field) => (
            <Input
              label={FIELD_LABELS.boothCapacity}
              description="Booths available to exhibitors. 0 offers no booths, and the form asks for no booth request."
              type="number"
              className="max-w-40"
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        {checkboxField({
          name: "additionalAttendeesRegistrationOpen",
        })}
      </Section>

      <Section title="Access">
        {checkboxField({
          name: "hidden",
          description:
            "Left out of the public conference list. Applicants then need the form URL, which carries an invite code generated on save.",
        })}
        {saved?.hidden && (
          <Text size="sm">
            Form URL:{" "}
            <Link href={saved.applicationFormUrl} className="break-all">
              {saved.applicationFormUrl}
            </Link>
          </Text>
        )}
        {checkboxField({
          name: "allowRestrictedAccess",
          description:
            "Staff restricted to some conferences may manage this one when they can read its GitHub repository.",
        })}
      </Section>

      <Section title="Integrations">
        <form.Field name="githubRepo">
          {(field) => (
            <Input
              label={FIELD_LABELS.githubRepo}
              description="Where the sponsor list is published: owner/repo[@branch]:path/to/file. Empty publishes nothing."
              placeholder="ruby-no-kai/rubykaigi.org@master:data/year_2026/sponsors.yml"
              className="font-mono"
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        <form.Field name="githubRepoImagesPath">
          {(field) => (
            <Input
              label={FIELD_LABELS.githubRepoImagesPath}
              description="Directory of the repository for the images of accepted sponsor events, without a trailing slash. Empty publishes none."
              placeholder="images"
              className="font-mono"
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        <form.Field name="titoSlug">
          {(field) => (
            <Input
              label={FIELD_LABELS.titoSlug}
              description="account_slug/event_slug. Empty issues no tickets through Ti.to."
              placeholder="rubykaigi/2026"
              className="font-mono"
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        <form.Field name="titoBoothPaidFlatDiscountAmount">
          {(field) => (
            <Input
              label={FIELD_LABELS.titoBoothPaidFlatDiscountAmount}
              description="Taken off each booth staff ticket an exhibitor pays for, in the Ti.to event's currency."
              inputMode="decimal"
              className="max-w-60"
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
      </Section>

      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          errored: erroredFields(state.fieldMeta, CONFERENCE_LAYOUT),
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
            <Button type="submit" variant="primary" loading={isSubmitting} disabled={isRestricted}>
              {saved === undefined ? "Create" : "Save"}
            </Button>
          </SaveBar>
        )}
      </form.Subscribe>
    </form>
  );
}

function FieldError({ errors }: { errors: readonly unknown[] }) {
  const message = joined(errors);
  if (message === undefined) return null;
  return (
    <Text variant="error" size="sm">
      {message}
    </Text>
  );
}
