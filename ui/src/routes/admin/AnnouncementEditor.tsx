import {
  Badge,
  Button,
  Checkbox,
  Input,
  InputArea,
  Link,
  Loader,
  Select,
  Text,
} from "@cloudflare/kumo";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import { generatePath, useNavigate, useParams, useSearchParams } from "react-router";
import { useSWRConfig } from "swr";
import type {
  AdminAnnouncement,
  AdminAnnouncementSummary,
} from "../../gen/rubykaigi/sponsor_app/admin_announcements_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { ProblemType } from "../../gen/rubykaigi/sponsor_app/problem_pb.ts";
import { fieldViolations, problemTypeOf } from "../../lib/errors.ts";
import type { FormErrors } from "../../lib/errors.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { toastManager } from "../../lib/toast.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import { AnnouncementBadges } from "./AnnouncementBadges.tsx";
import {
  ANNOUNCEMENT_LAYOUT,
  FIELD_LABELS,
  announcementId,
  announcementInputFrom,
  announcementPath,
  announcementValuesFrom,
  defaultLocale,
  localeItems,
  parseAnnouncementId,
} from "./announcementForm.ts";
import type { AnnouncementValues } from "./announcementForm.ts";
import {
  ErrorList,
  joined,
  SaveBar,
  SaveErrorBanner,
  Section,
  useFieldReveal,
} from "./FormParts.tsx";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";

// One page for new and edit, at the paths HAML serves them. A new announcement started from an
// issue's "+" tab carries the issue in `?issue=` and is written as another locale of it.
export default function AnnouncementEditor() {
  const { slug = "", id } = useParams();
  const [searchParams] = useSearchParams();
  if (id !== undefined) {
    const key = parseAnnouncementId(id);
    if (key === undefined) return <NotFound />;
    return <EditAnnouncement key={id} slug={slug} target={key} />;
  }
  const newIssue = searchParams.get("issue") || undefined;
  if (newIssue === undefined) return <NewAnnouncement slug={slug} issueLocales={[]} />;
  return <NewLocale key={newIssue} slug={slug} issue={newIssue} />;
}

function EditAnnouncement({
  slug,
  target,
}: {
  slug: string;
  target: { issue: string; locale: string };
}) {
  const { data, error } = useRpc(AdminService.method.getAnnouncement, {
    conferenceSlug: slug,
    ...target,
  });
  useConferenceTitle(
    slug,
    `Edit announcement: ${data?.announcement?.title ?? announcementId(target.issue, target.locale)}`,
    "Announcements",
  );

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const saved = data.announcement;
  if (saved === undefined) throw new Error("GetAnnouncement returned no announcement");
  return (
    <Editor
      slug={slug}
      issue={saved.issue}
      issueLocales={data.issue?.announcements ?? []}
      saved={saved}
    />
  );
}

// Another locale of an existing issue, which the list holds with its other locales.
function NewLocale({ slug, issue }: { slug: string; issue: string }) {
  const { data, error } = useRpc(AdminService.method.listAnnouncements, { conferenceSlug: slug });

  if (error !== undefined && data === undefined) throw error;
  const found = data?.issues.find((candidate) => candidate.issue === issue);
  if (data !== undefined && found === undefined) return <NotFound />;
  return <NewAnnouncement slug={slug} issue={issue} issueLocales={found?.announcements} />;
}

// Renders the loader while the issue's locales are on their way.
function NewAnnouncement({
  slug,
  issue,
  issueLocales,
}: {
  slug: string;
  issue?: string;
  issueLocales: readonly AdminAnnouncementSummary[] | undefined;
}) {
  useConferenceTitle(slug, "New announcement", "Announcements");

  if (issueLocales === undefined) return <Loader size="lg" />;
  return <Editor slug={slug} issue={issue} issueLocales={issueLocales} saved={undefined} />;
}

function Editor({
  slug,
  issue,
  issueLocales,
  saved,
}: {
  slug: string;
  // Unset for an announcement starting an issue.
  issue: string | undefined;
  // Every locale the issue is written in, the saved announcement's included.
  issueLocales: readonly AdminAnnouncementSummary[];
  saved: AdminAnnouncement | undefined;
}) {
  const navigate = useNavigate();
  const { mutate } = useSWRConfig();
  const createAnnouncement = useRpcMutation(AdminService.method.createAnnouncement);
  const updateAnnouncement = useRpcMutation(AdminService.method.updateAnnouncement);
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();
  const conferenceName = useConferenceName(slug);
  const writtenLocales = issueLocales.map(({ locale }) => locale);
  // One above a behind locale's own revision may still be behind, so such a locale only catches up.
  const offersNewRevision =
    saved !== undefined && !issueLocales.find(({ locale }) => locale === saved.locale)?.behind;

  const form = useForm({
    defaultValues: announcementValuesFrom(saved, {
      locale: defaultLocale(writtenLocales),
      sibling: issueLocales[0],
    }),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      const input = announcementInputFrom(value);
      let result: AdminAnnouncement | undefined;
      try {
        const response =
          saved === undefined
            ? await createAnnouncement.trigger({ conferenceSlug: slug, issue, input })
            : await updateAnnouncement.trigger({
                conferenceSlug: slug,
                issue: saved.issue,
                locale: saved.locale,
                input,
              });
        result = response.announcement;
      } catch (error) {
        setSaveError(error);
        rejection.reject(formApi, value, saveErrors(error));
        const [first] = erroredFields(formApi.state.fieldMeta, ANNOUNCEMENT_LAYOUT);
        if (first !== undefined) reveal(first.path);
        return;
      }
      setSaveError(undefined);
      if (result === undefined) return;
      toastManager.add({
        variant: "success",
        title: `${saved === undefined ? "Created" : "Saved"} the ${result.locale} announcement`,
      });
      // Leaves before revalidating, as the announcement may have moved off this page's locale.
      await navigate(announcementPath(slug, result.issue, result.locale));
      await mutate(
        (key) =>
          isRpcKeyOf(key, AdminService.method.listAnnouncements) ||
          isRpcKeyOf(key, AdminService.method.getAnnouncement),
      );
    },
  });

  const checkboxField = (
    name: Extract<
      keyof AnnouncementValues,
      "pinned" | "exhibitorsOnly" | "published" | "newRevision"
    >,
    description: string,
  ) => (
    <form.Field name={name}>
      {(field) => (
        <div className="flex max-w-xs flex-col gap-1" data-field={field.name}>
          <Checkbox
            label={FIELD_LABELS[name]}
            checked={field.state.value}
            onCheckedChange={(checked) => field.handleChange(checked)}
            variant={field.state.meta.errors.length > 0 ? "error" : "default"}
          />
          <Text variant="secondary" size="sm">
            {description}
          </Text>
          <ErrorList errors={field.state.meta.errors} />
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
        crumbs={[
          { label: conferenceName, href: generatePath(paths.conference, { slug }) },
          { label: "Announcements", href: generatePath(paths.announcements, { slug }) },
          ...(saved === undefined
            ? []
            : [{ label: saved.title, href: announcementPath(slug, saved.issue, saved.locale) }]),
        ]}
        title={saved === undefined ? "New announcement" : "Edit announcement"}
      />

      {issue !== undefined && (
        <Section title={`Issue ${issue}`}>
          {issueLocales.length === 0 ? (
            <Text variant="secondary">Not written yet.</Text>
          ) : (
            <ul className="flex flex-col gap-1">
              {issueLocales.map((locale) => {
                const editing = locale.locale === saved?.locale;
                return (
                  <li key={locale.locale} className="flex flex-wrap items-center gap-2">
                    <Text variant="mono" as="span">
                      {locale.locale}
                    </Text>
                    {editing ? (
                      <Text as="span">{locale.title}</Text>
                    ) : (
                      <Link href={announcementPath(slug, issue, locale.locale)}>
                        {locale.title}
                      </Link>
                    )}
                    {editing && <Badge variant="info">Editing</Badge>}
                    <AnnouncementBadges
                      pinned={locale.pinned}
                      exhibitorsOnly={locale.exhibitorsOnly}
                      published={locale.published}
                      behind={locale.behind}
                    />
                  </li>
                );
              })}
            </ul>
          )}
        </Section>
      )}

      <Section title="Announcement">
        <form.Field name="locale">
          {(field) =>
            saved === undefined ? (
              <div data-field={field.name}>
                <Select
                  label={FIELD_LABELS.locale}
                  className="min-w-40"
                  value={field.state.value}
                  onValueChange={(value) => field.handleChange(String(value ?? ""))}
                  items={localeItems(writtenLocales, field.state.value)}
                  error={joined(field.state.meta.errors)}
                />
              </div>
            ) : (
              <div className="flex flex-col gap-1" data-field={field.name}>
                <Text bold>{FIELD_LABELS.locale}</Text>
                <Text variant="mono">{field.state.value}</Text>
              </div>
            )
          }
        </form.Field>
        <form.Field name="title">
          {(field) => (
            <Input
              label={FIELD_LABELS.title}
              data-field={field.name}
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
              description="Markdown supported"
              data-field={field.name}
              autoResize
              minRows={12}
              maxRows={40}
              value={field.state.value}
              onValueChange={field.handleChange}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        {checkboxField("pinned", "Lists it ahead of the unpinned announcements.")}
        {checkboxField("exhibitorsOnly", "Only sponsorships with a booth assigned can read it.")}
      </Section>

      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          errored: erroredFields(state.fieldMeta, ANNOUNCEMENT_LAYOUT),
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
            {checkboxField("published", "Sponsors can read it. Unchecked keeps it a draft.")}
            {offersNewRevision &&
              checkboxField(
                "newRevision",
                "Marks the other locales as behind, awaiting a translation of this text. Unchecked, saving marks this locale as up to date.",
              )}
            <Button type="submit" variant="primary" loading={isSubmitting}>
              {saved === undefined ? "Create" : "Save"}
            </Button>
          </SaveBar>
        )}
      </form.Subscribe>
    </form>
  );
}

// Field violations go to their fields. A locale the issue is already written in is the locale
// field's problem.
function saveErrors(error: unknown): FormErrors {
  const errors = fieldViolations(error, { prefix: "input." });
  if (problemTypeOf(error) === ProblemType.CONFLICT && errors.form !== undefined) {
    return { fields: { ...errors.fields, locale: errors.form } };
  }
  return errors;
}
