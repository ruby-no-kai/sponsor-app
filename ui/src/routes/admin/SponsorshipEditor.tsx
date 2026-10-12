import { Button, Checkbox, Input, InputArea, Loader, Radio, Select, Text } from "@cloudflare/kumo";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import type { ReactNode } from "react";
import { generatePath, useNavigate, useParams } from "react-router";
import { useSWRConfig } from "swr";
import type { AdminSponsorship } from "../../gen/rubykaigi/sponsor_app/admin_sponsorship_pb.ts";
import type { AdminServiceGetSponsorshipResponse } from "../../gen/rubykaigi/sponsor_app/admin_sponsorships_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import type { FormErrors } from "../../lib/errors.ts";
import { erroredFields } from "../../lib/fieldErrors.ts";
import { idFromParam, idToInput } from "../../lib/forms.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { toastManager } from "../../lib/toast.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import { joined, SaveBar, SaveErrorBanner, Section, useFieldReveal } from "./FormParts.tsx";
import type { FieldOf } from "./FormParts.tsx";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";
import {
  FIELD_LABELS,
  SPONSORSHIP_LAYOUT,
  fallbackOptionItems,
  formValuesFrom,
  inputFrom,
  planTerms,
  wordCount,
} from "./sponsorshipForm.ts";

export default function SponsorshipEditor() {
  const { slug = "", id = "" } = useParams();
  const sponsorshipId = idFromParam(id);
  if (sponsorshipId === undefined) return <NotFound />;
  return <Loaded key={id} slug={slug} sponsorshipId={sponsorshipId} />;
}

function Loaded({ slug, sponsorshipId }: { slug: string; sponsorshipId: bigint }) {
  const { data, error } = useRpc(AdminService.method.getSponsorship, {
    conferenceSlug: slug,
    sponsorshipId,
  });
  useConferenceTitle(slug, `Edit sponsorship: ${data?.sponsorship?.name ?? sponsorshipId}`);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  if (data.sponsorship === undefined) throw new Error("GetSponsorship returned no sponsorship");

  return <Editor slug={slug} response={data} sponsorship={data.sponsorship} />;
}

function Editor({
  slug,
  response,
  sponsorship,
}: {
  slug: string;
  response: AdminServiceGetSponsorshipResponse;
  sponsorship: AdminSponsorship;
}) {
  const navigate = useNavigate();
  const { mutate } = useSWRConfig();
  const updateSponsorship = useRpcMutation(AdminService.method.updateSponsorship);
  const conferenceName = useConferenceName(slug);
  const sponsorshipPath = generatePath(paths.sponsorship, { slug, id: idToInput(sponsorship.id) });
  const plans = response.planChoices;
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();

  const form = useForm({
    defaultValues: formValuesFrom(sponsorship),
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      const reject = (errors: FormErrors) => {
        rejection.reject(formApi, value, errors);
        const [first] = erroredFields(formApi.state.fieldMeta, SPONSORSHIP_LAYOUT);
        if (first !== undefined) reveal(first.path);
      };
      let input;
      try {
        input = inputFrom(value);
      } catch (error) {
        if (!(error instanceof RangeError)) throw error;
        setSaveError(undefined);
        reject({ fields: { numberOfAdditionalAttendees: "Enter a whole number" } });
        return;
      }
      let result: AdminSponsorship | undefined;
      try {
        const saved = await updateSponsorship.trigger({
          conferenceSlug: slug,
          sponsorshipId: sponsorship.id,
          input,
        });
        result = saved.sponsorship;
      } catch (error) {
        setSaveError(error);
        reject(fieldViolations(error, { prefix: "input." }));
        return;
      }
      setSaveError(undefined);
      if (result === undefined) return;
      toastManager.add({ variant: "success", title: `Saved ${result.name}` });
      await mutate(
        (key) =>
          isRpcKeyOf(key, AdminService.method.getSponsorship) ||
          isRpcKeyOf(key, AdminService.method.getConference),
      );
      await navigate(sponsorshipPath);
    },
  });

  const textInput = (
    field: FieldOf<string>,
    label: string,
    { type = "text", description }: { type?: string; description?: ReactNode } = {},
  ) => (
    <Input
      label={label}
      description={description}
      type={type}
      data-field={field.name}
      value={field.state.value}
      onChange={(event) => field.handleChange(event.target.value)}
      onBlur={field.handleBlur}
      error={joined(field.state.meta.errors)}
    />
  );

  const textArea = (field: FieldOf<string>, label: string, description?: ReactNode) => (
    <InputArea
      label={label}
      description={description}
      data-field={field.name}
      autoResize
      minRows={3}
      maxRows={16}
      value={field.state.value}
      onValueChange={field.handleChange}
      onBlur={field.handleBlur}
      error={joined(field.state.meta.errors)}
    />
  );

  const checkbox = (field: FieldOf<boolean>, label: string, description?: ReactNode) => (
    <div className="flex flex-col gap-1" data-field={field.name}>
      <Checkbox
        label={label}
        checked={field.state.value}
        onCheckedChange={(checked) => field.handleChange(checked === true)}
      />
      {description !== undefined && (
        <Text variant="secondary" size="sm">
          {description}
        </Text>
      )}
      <FieldError errors={field.state.meta.errors} />
    </div>
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
          { label: sponsorship.name, href: sponsorshipPath },
        ]}
        title="Edit sponsorship"
      />

      <Section title="Contact">
        <div className="grid gap-3 md:grid-cols-2">
          <form.Field name="contact.email">
            {(field) => textInput(field, FIELD_LABELS.email, { type: "email" })}
          </form.Field>
          <form.Field name="contact.emailCc">
            {(field) =>
              textInput(field, FIELD_LABELS.emailCc, {
                description: "Separated by commas or semicolons.",
              })
            }
          </form.Field>
          <form.Field name="contact.name">
            {(field) => textInput(field, FIELD_LABELS.name)}
          </form.Field>
          <form.Field name="contact.organization">
            {(field) => textInput(field, FIELD_LABELS.organization)}
          </form.Field>
          <form.Field name="contact.unit">
            {(field) => textInput(field, FIELD_LABELS.unit, { description: "Optional." })}
          </form.Field>
          <form.Field name="contact.address">
            {(field) => textInput(field, FIELD_LABELS.address)}
          </form.Field>
        </div>
      </Section>

      <Section title="Billing">
        <form.Field name="specifiesBillingContact">
          {(field) => checkbox(field, FIELD_LABELS.specifiesBillingContact)}
        </form.Field>
        <form.Subscribe selector={(state) => state.values.specifiesBillingContact}>
          {(specifiesBillingContact) =>
            specifiesBillingContact && (
              <div className="grid gap-3 md:grid-cols-2">
                <form.Field name="alternateBillingContact.email">
                  {(field) => textInput(field, FIELD_LABELS.email, { type: "email" })}
                </form.Field>
                <form.Field name="alternateBillingContact.name">
                  {(field) => textInput(field, FIELD_LABELS.name)}
                </form.Field>
                <form.Field name="alternateBillingContact.organization">
                  {(field) => textInput(field, FIELD_LABELS.organization)}
                </form.Field>
                <form.Field name="alternateBillingContact.unit">
                  {(field) => textInput(field, FIELD_LABELS.unit, { description: "Optional." })}
                </form.Field>
                <form.Field name="alternateBillingContact.address">
                  {(field) => textInput(field, FIELD_LABELS.address)}
                </form.Field>
              </div>
            )
          }
        </form.Subscribe>
        <form.Field name="billingRequest">
          {(field) => textArea(field, FIELD_LABELS.billingRequest, "Blank removes it.")}
        </form.Field>
      </Section>

      <Section title="Plan">
        <form.Field name="planId">
          {(field) => (
            <div data-field={field.name}>
              <Radio.Group
                legend={FIELD_LABELS.planId}
                value={field.state.value}
                onValueChange={(value) => field.handleChange(String(value))}
                error={joined(field.state.meta.errors)}
              >
                {plans.map((plan) => (
                  <Radio.Item
                    key={plan.id.toString()}
                    value={idToInput(plan.id)}
                    label={
                      <span>
                        {plan.name}{" "}
                        <Text variant="secondary" size="sm" as="span">
                          {planTerms(plan)}
                        </Text>
                      </span>
                    }
                  />
                ))}
                <Radio.Item value="" label="Other (undetermined)" />
              </Radio.Group>
            </div>
          )}
        </form.Field>
        <form.Field name="customizationRequest">
          {(field) => textArea(field, FIELD_LABELS.customizationRequest, "Blank removes it.")}
        </form.Field>
        <form.Field name="customization">
          {(field) =>
            checkbox(
              field,
              FIELD_LABELS.customization,
              "Until it is, the sponsor is published under its plan.",
            )
          }
        </form.Field>
        <form.Field name="customizationName">
          {(field) =>
            textInput(field, FIELD_LABELS.customizationName, {
              description: "Blank arranges none.",
            })
          }
        </form.Field>
      </Section>

      <Section title="Booth">
        <form.Subscribe selector={(state) => state.values.planId}>
          {(planId) => {
            const plan = plans.find((candidate) => idToInput(candidate.id) === planId);
            return (
              <form.Field name="boothRequested">
                {(field) =>
                  checkbox(
                    field,
                    FIELD_LABELS.boothRequested,
                    plan !== undefined && plan.boothSize === 0
                      ? "The selected plan offers no booth."
                      : undefined,
                  )
                }
              </form.Field>
            );
          }}
        </form.Subscribe>
        <form.Field name="boothAssigned">
          {(field) => checkbox(field, FIELD_LABELS.boothAssigned)}
        </form.Field>
      </Section>

      <Section title="Fallback option">
        <form.Field name="fallbackOption">
          {(field) => (
            <div data-field={field.name}>
              <Select
                label={FIELD_LABELS.fallbackOption}
                className="min-w-60"
                value={field.state.value}
                onValueChange={(value) => field.handleChange(String(value ?? ""))}
                items={fallbackOptionItems(response.fallbackOptionChoices, field.state.value)}
                error={joined(field.state.meta.errors)}
              />
            </div>
          )}
        </form.Field>
      </Section>

      <Section title="Information">
        <form.Field name="name">{(field) => textInput(field, FIELD_LABELS.name)}</form.Field>
        <form.Field name="url">{(field) => textInput(field, FIELD_LABELS.url)}</form.Field>
        <form.Subscribe selector={(state) => state.values.planId}>
          {(planId) => {
            const plan = plans.find((candidate) => idToInput(candidate.id) === planId);
            return (
              <form.Field name="profile">
                {(field) =>
                  textArea(
                    field,
                    FIELD_LABELS.profile,
                    plan === undefined
                      ? `${wordCount(field.state.value)} words`
                      : `${wordCount(field.state.value)} words; ${plan.name} allows ${plan.wordsLimit} (refused past ${plan.wordsLimitHard})`,
                  )
                }
              </form.Field>
            );
          }}
        </form.Subscribe>
      </Section>

      <Section title="Note from the sponsor">
        <form.Field name="note">
          {(field) => textArea(field, FIELD_LABELS.note, "Blank removes it.")}
        </form.Field>
      </Section>

      <Section title="Tickets">
        <form.Field name="numberOfAdditionalAttendees">
          {(field) =>
            textInput(field, FIELD_LABELS.numberOfAdditionalAttendees, {
              type: "number",
              description: "Tickets beyond the plan's. Blank grants none.",
            })
          }
        </form.Field>
      </Section>

      <Section title="Administrative flags">
        <form.Field name="accepted">{(field) => checkbox(field, FIELD_LABELS.accepted)}</form.Field>
        <form.Field name="suspended">
          {(field) =>
            checkbox(
              field,
              FIELD_LABELS.suspended,
              "Leaves the sponsor out of the sponsor list on the conference website, such as for a problem in its introduction.",
            )
          }
        </form.Field>
      </Section>

      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          errored: erroredFields(state.fieldMeta, SPONSORSHIP_LAYOUT),
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

function FieldError({ errors }: { errors: readonly unknown[] }) {
  const message = joined(errors);
  if (message === undefined) return null;
  return (
    <Text variant="error" size="sm">
      {message}
    </Text>
  );
}
