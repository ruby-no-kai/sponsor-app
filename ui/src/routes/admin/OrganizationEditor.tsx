import { Banner, Button, Checkbox, Input, Loader, Text } from "@cloudflare/kumo";
import { WarningIcon } from "@phosphor-icons/react";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import { generatePath, useNavigate, useParams } from "react-router";
import { useSWRConfig } from "swr";
import type { AdminOrganization } from "../../gen/rubykaigi/sponsor_app/admin_organizations_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { toastManager } from "../../lib/toast.ts";
import { paths } from "../paths.ts";
import {
  ErrorList,
  joined,
  SaveBar,
  SaveErrorBanner,
  Section,
  useFieldReveal,
} from "./FormParts.tsx";
import {
  FIELD_LABELS,
  ORGANIZATION_LAYOUT,
  organizationInputFrom,
  organizationValuesFrom,
} from "./organizationForm.ts";

// One page for new and edit, at the paths HAML serves them.
export default function OrganizationEditor() {
  const { domain } = useParams();
  const current = useRpc(
    AdminService.method.getOrganization,
    domain === undefined ? null : { domain },
  );
  const viewer = useRpc(AdminService.method.getViewer, {}).data?.staff;
  useDocumentTitle(
    domain === undefined ? "New organization" : "Edit organization",
    current.data?.organization?.name ?? domain,
  );

  if (current.error !== undefined && current.data === undefined) throw current.error;
  if (domain !== undefined && current.data === undefined) return <Loader size="lg" />;

  return (
    <Editor
      key={domain ?? ""}
      saved={current.data?.organization}
      isRestricted={viewer?.restricted ?? false}
    />
  );
}

function Editor({
  saved,
  isRestricted,
}: {
  saved: AdminOrganization | undefined;
  isRestricted: boolean;
}) {
  const navigate = useNavigate();
  const { mutate } = useSWRConfig();
  const createOrganization = useRpcMutation(AdminService.method.createOrganization);
  const updateOrganization = useRpcMutation(AdminService.method.updateOrganization);
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();

  const form = useForm({
    defaultValues: organizationValuesFrom(saved),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      const input = organizationInputFrom(value);
      let result: AdminOrganization | undefined;
      try {
        const response =
          saved === undefined
            ? await createOrganization.trigger({ input })
            : await updateOrganization.trigger({ domain: saved.domain, input });
        result = response.organization;
      } catch (error) {
        setSaveError(error);
        rejection.reject(formApi, value, fieldViolations(error, { prefix: "input." }));
        const [first] = erroredFields(formApi.state.fieldMeta, ORGANIZATION_LAYOUT);
        if (first !== undefined) reveal(first.path);
        return;
      }
      setSaveError(undefined);
      if (result === undefined) return;
      toastManager.add({
        variant: "success",
        title: `${saved === undefined ? "Created" : "Saved"} the organization ${result.name}`,
      });
      // Leaves first, as revalidating a GetOrganization of a domain that moved answers not_found.
      await navigate(generatePath(paths.organization, { domain: result.domain }));
      await mutate(
        (key) =>
          isRpcKeyOf(key, AdminService.method.listOrganizations) ||
          isRpcKeyOf(key, AdminService.method.getOrganization),
      );
    },
  });

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
          { label: "Organizations", href: paths.organizations },
          ...(saved === undefined
            ? []
            : [
                {
                  label: saved.name,
                  href: generatePath(paths.organization, { domain: saved.domain }),
                },
              ]),
        ]}
        title={saved === undefined ? "New organization" : "Edit organization"}
      />

      {isRestricted && (
        <Banner
          variant="alert"
          icon={<WarningIcon />}
          title="Restricted staff cannot save organizations"
          description="An organization spans conferences. Ask a staff member with full access to make this change."
        />
      )}

      <Section title="Organization">
        <form.Field name="name">
          {(field) => (
            <Input
              label={FIELD_LABELS.name}
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        <form.Field name="domain">
          {(field) => (
            <Input
              label={FIELD_LABELS.domain}
              description="The email domain that identifies the organization, in lowercase. Applicants from it join the organization."
              placeholder="example.com"
              className="font-mono"
              data-field={field.name}
              value={field.state.value}
              onChange={(event) => field.handleChange(event.target.value)}
              onBlur={field.handleBlur}
              error={joined(field.state.meta.errors)}
            />
          )}
        </form.Field>
        <form.Field name="autoAcceptanceDisabled">
          {(field) => (
            <div className="flex flex-col gap-1" data-field={field.name}>
              <Checkbox
                label={FIELD_LABELS.autoAcceptanceDisabled}
                checked={field.state.value}
                onCheckedChange={(checked) => field.handleChange(checked)}
                variant={field.state.meta.errors.length > 0 ? "error" : "default"}
              />
              <Text variant="secondary" size="sm">
                Its applications wait for the organizers' acceptance even on a plan that accepts
                them as soon as they are submitted.
              </Text>
              <ErrorList errors={field.state.meta.errors} />
            </div>
          )}
        </form.Field>
      </Section>

      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          errored: erroredFields(state.fieldMeta, ORGANIZATION_LAYOUT),
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
