import { Badge, Button, Checkbox, Input, Loader, Text } from "@cloudflare/kumo";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import type { ReactNode } from "react";
import { generatePath, useNavigate, useParams } from "react-router";
import { useSWRConfig } from "swr";
import type { AdminPlan } from "../../gen/rubykaigi/sponsor_app/admin_plans_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import type { FormErrors } from "../../lib/errors.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import { idFromParam } from "../../lib/forms.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { toastManager } from "../../lib/toast.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import {
  DateTimeInput,
  ErrorList,
  joined,
  SaveBar,
  SaveErrorBanner,
  Section,
  useFieldReveal,
} from "./FormParts.tsx";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";
import { FIELD_LABELS, PLAN_LAYOUT, planInputFrom, planValuesFrom } from "./planForm.ts";
import type { PlanTextField } from "./planForm.ts";

// One page for new and edit, at the paths HAML serves them.
export default function PlanEditor() {
  const { slug = "", id } = useParams();
  if (id === undefined) return <NewPlan slug={slug} />;
  const planId = idFromParam(id);
  if (planId === undefined) return <NotFound />;
  return <EditPlan key={id} slug={slug} planId={planId} />;
}

function NewPlan({ slug }: { slug: string }) {
  useConferenceTitle(slug, "New plan");
  return <Editor slug={slug} saved={undefined} />;
}

function EditPlan({ slug, planId }: { slug: string; planId: bigint }) {
  const { data, error } = useRpc(AdminService.method.getPlan, { conferenceSlug: slug, planId });
  useConferenceTitle(slug, `Edit plan: ${data?.plan?.name ?? planId}`);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  return <Editor slug={slug} saved={data.plan} />;
}

function Editor({ slug, saved }: { slug: string; saved: AdminPlan | undefined }) {
  const conferenceName = useConferenceName(slug);
  const navigate = useNavigate();
  const { mutate } = useSWRConfig();
  const createPlan = useRpcMutation(AdminService.method.createPlan);
  const updatePlan = useRpcMutation(AdminService.method.updatePlan);
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();

  const form = useForm({
    defaultValues: planValuesFrom(saved),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      const reject = (errors: FormErrors) => {
        rejection.reject(formApi, value, errors);
        const [first] = erroredFields(formApi.state.fieldMeta, PLAN_LAYOUT);
        if (first !== undefined) reveal(first.path);
      };
      const built = planInputFrom(value);
      if (built.kind === "invalid") {
        setSaveError(undefined);
        reject({ fields: built.fields });
        return;
      }
      let result: AdminPlan | undefined;
      try {
        const response =
          saved === undefined
            ? await createPlan.trigger({ conferenceSlug: slug, input: built.input })
            : await updatePlan.trigger({
                conferenceSlug: slug,
                planId: saved.id,
                input: built.input,
              });
        result = response.plan;
      } catch (error) {
        setSaveError(error);
        reject(fieldViolations(error, { prefix: "input." }));
        return;
      }
      setSaveError(undefined);
      if (result === undefined) return;
      toastManager.add({
        variant: "success",
        title: `${saved === undefined ? "Created" : "Saved"} the plan ${result.name}`,
      });
      // Before leaving, so this page's GetPlan is refetched rather than left stale in the cache.
      await mutate(
        (key) =>
          isRpcKeyOf(key, AdminService.method.listPlans) ||
          isRpcKeyOf(key, AdminService.method.getPlan) ||
          isRpcKeyOf(key, AdminService.method.getConference),
      );
      await navigate(generatePath(paths.plans, { slug }));
    },
  });

  const textField = (
    name: PlanTextField,
    props: {
      description?: ReactNode;
      type?: string;
      inputMode?: "decimal";
      className?: string;
    } = {},
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

  const checkboxField = (name: "autoAcceptance" | "talkable") => (
    <form.Field name={name}>
      {(field) => (
        <div className="flex flex-col gap-1" data-field={field.name}>
          <Checkbox
            label={FIELD_LABELS[name]}
            checked={field.state.value}
            onCheckedChange={(checked) => field.handleChange(checked)}
            variant={field.state.meta.errors.length > 0 ? "error" : "default"}
          />
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
          { label: "Plans", href: generatePath(paths.plans, { slug }) },
        ]}
        title={saved === undefined ? "New plan" : "Edit plan"}
        subtitle={saved?.name}
      />

      {saved !== undefined && (
        <Text variant="secondary">
          {saved.activeSponsorshipCount} of {saved.capacity} taken by active sponsorships.{" "}
          {saved.soldOut && <Badge variant="error">Sold out</Badge>}{" "}
          {saved.closed && <Badge variant="warning">Closed</Badge>}
        </Text>
      )}

      <Section title="Plan">
        {textField("name", {
          description: "Fallback option conditions name the plan by it.",
        })}
        {textField("summary", { description: "One line. Optional." })}
        {textField("rank", {
          type: "number",
          description: "Plans are listed lowest rank first.",
          className: "max-w-40",
        })}
      </Section>

      <Section title="Price">
        {textField("priceText", {
          description: "What the application form shows, such as 3,000,000 JPY.",
        })}
        <div className="grid gap-4 md:grid-cols-2">
          {textField("price", {
            inputMode: "decimal",
            description:
              "A decimal number, such as 3000000. Expense reports are offset against it.",
            className: "font-mono",
          })}
          {textField("priceBooth", {
            inputMode: "decimal",
            description: "Added to the fee when a booth is assigned.",
            className: "font-mono",
          })}
        </div>
      </Section>

      <Section title="Capacity and benefits">
        <div className="grid gap-4 md:grid-cols-2">
          {textField("capacity", {
            type: "number",
            description: "Active sponsorships the plan admits.",
          })}
          {textField("numberOfGuests", {
            type: "number",
            description: "Conference tickets each sponsorship includes.",
          })}
          {textField("boothSize", {
            type: "number",
            description: "Empty or 0 makes the plan ineligible for a booth.",
          })}
          {textField("wordsLimit", {
            type: "number",
            description: "About how many words a sponsor's profile may have.",
          })}
        </div>
        {checkboxField("talkable")}
      </Section>

      <Section title="Applications">
        <form.Field name="closesAt">
          {(field) => (
            <div className="max-w-md">
              <DateTimeInput
                field={field}
                label={FIELD_LABELS.closesAt}
                description="Empty keeps the plan open as long as the application form is. In your browser's time zone."
              />
            </div>
          )}
        </form.Field>
        {checkboxField("autoAcceptance")}
      </Section>

      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          errored: erroredFields(state.fieldMeta, PLAN_LAYOUT),
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
